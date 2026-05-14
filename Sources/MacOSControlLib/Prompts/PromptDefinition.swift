import Foundation

public struct PromptDefinition: Equatable {

    public let name: String
    public let description: String
    public let promptVersion: Int
    public let arguments: [PromptTemplate.ArgumentSpec]
    public let body: String

    public enum LoadError: Error, Equatable {
        case missingFrontMatter
        case missingKey(String)
        case invalidPromptVersion
        case malformedArguments(String)
    }

    public init(
        name: String,
        description: String,
        promptVersion: Int,
        arguments: [PromptTemplate.ArgumentSpec],
        body: String
    ) {
        self.name = name
        self.description = description
        self.promptVersion = promptVersion
        self.arguments = arguments
        self.body = body
    }

    public static func parse(_ source: String) throws -> PromptDefinition {
        let lines = source.components(separatedBy: "\n")
        guard let firstDelim = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            throw LoadError.missingFrontMatter
        }
        // Front matter must start at line 0; allow leading blank lines.
        let preDelim = lines.prefix(firstDelim).joined()
        if !preDelim.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LoadError.missingFrontMatter
        }
        let afterFirst = firstDelim + 1
        guard let secondDelim = lines[afterFirst...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            throw LoadError.missingFrontMatter
        }

        let frontMatterLines = Array(lines[afterFirst..<secondDelim])
        let bodyLines = Array(lines[(secondDelim + 1)...])
        // Drop leading blank lines from body, preserve trailing.
        var bodyTrimmed = bodyLines
        while let first = bodyTrimmed.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
            bodyTrimmed.removeFirst()
        }
        let body = bodyTrimmed.joined(separator: "\n")

        let frontMatter = try parseFrontMatter(frontMatterLines)

        guard let name = frontMatter.scalars["name"] else { throw LoadError.missingKey("name") }
        guard let description = frontMatter.scalars["description"] else { throw LoadError.missingKey("description") }
        guard let versionString = frontMatter.scalars["prompt_version"] else { throw LoadError.missingKey("prompt_version") }
        guard let promptVersion = Int(versionString) else { throw LoadError.invalidPromptVersion }

        return PromptDefinition(
            name: name,
            description: description,
            promptVersion: promptVersion,
            arguments: frontMatter.arguments,
            body: body
        )
    }

    // MARK: - Front-matter parser
    //
    // Supports a small subset of YAML sufficient for prompt definitions:
    //   key: value                              (unquoted scalar, trimmed)
    //   key: "value with: special chars"        (double-quoted scalar)
    //   arguments: []                           (empty inline list)
    //   arguments:
    //     - name: foo
    //       required: true
    //
    // Out of scope: nested mappings beyond `arguments`, multi-line scalars,
    // flow-style mappings. If we outgrow this, swap in Yams.

    private struct ParsedFrontMatter {
        var scalars: [String: String] = [:]
        var arguments: [PromptTemplate.ArgumentSpec] = []
    }

    private static func parseFrontMatter(_ lines: [String]) throws -> ParsedFrontMatter {
        var result = ParsedFrontMatter()
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index += 1
                continue
            }

            // Top-level keys are not indented.
            if line.first == " " || line.first == "\t" {
                throw LoadError.malformedArguments("unexpected indentation at line \(index): \(line)")
            }

            guard let colonRange = line.range(of: ":") else {
                throw LoadError.malformedArguments("expected 'key: value' at line \(index): \(line)")
            }
            let key = String(line[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            if key == "arguments" {
                if rawValue == "[]" || rawValue.isEmpty == false && rawValue == "[]" {
                    result.arguments = []
                    index += 1
                    continue
                }
                if rawValue.isEmpty {
                    // Multi-line list follows.
                    var argIndex = index + 1
                    var currentArg: (name: String?, required: Bool, description: String?) = (nil, false, nil)
                    func flush() throws {
                        if let name = currentArg.name {
                            result.arguments.append(
                                .init(name: name, required: currentArg.required, description: currentArg.description)
                            )
                        } else if currentArg.required || currentArg.description != nil {
                            throw LoadError.malformedArguments("argument entry missing name")
                        }
                        currentArg = (nil, false, nil)
                    }
                    while argIndex < lines.count {
                        let argLine = lines[argIndex]
                        let argTrimmed = argLine.trimmingCharacters(in: .whitespaces)
                        if argTrimmed.isEmpty {
                            argIndex += 1
                            continue
                        }
                        // A non-indented line ends the argument list.
                        if argLine.first != " " && argLine.first != "\t" {
                            break
                        }
                        if argTrimmed.hasPrefix("- ") {
                            try flush()
                            let entry = String(argTrimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                            try assignArgumentField(entry, into: &currentArg)
                        } else {
                            try assignArgumentField(argTrimmed, into: &currentArg)
                        }
                        argIndex += 1
                    }
                    try flush()
                    index = argIndex
                    continue
                }
                throw LoadError.malformedArguments("inline argument lists must be '[]' — got: \(rawValue)")
            }

            result.scalars[key] = parseScalarValue(rawValue)
            index += 1
        }
        return result
    }

    private static func assignArgumentField(
        _ entry: String,
        into current: inout (name: String?, required: Bool, description: String?)
    ) throws {
        guard let colonRange = entry.range(of: ":") else {
            throw LoadError.malformedArguments("expected 'key: value' in argument entry: \(entry)")
        }
        let key = String(entry[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let value = parseScalarValue(String(entry[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces))
        switch key {
        case "name":
            current.name = value
        case "required":
            current.required = (value == "true")
        case "description":
            current.description = value
        default:
            throw LoadError.malformedArguments("unknown argument key \"\(key)\"")
        }
    }

    private static func parseScalarValue(_ raw: String) -> String {
        if raw.hasPrefix("\"") && raw.hasSuffix("\"") && raw.count >= 2 {
            let inner = raw.dropFirst().dropLast()
            return inner.replacingOccurrences(of: "\\\"", with: "\"")
        }
        return raw
    }
}
