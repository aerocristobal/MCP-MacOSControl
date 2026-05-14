import Foundation

public struct PromptTemplate: Equatable {

    public struct ArgumentSpec: Equatable {
        public let name: String
        public let required: Bool
        public let description: String?

        public init(name: String, required: Bool, description: String? = nil) {
            self.name = name
            self.required = required
            self.description = description
        }
    }

    public let content: String
    public let arguments: [ArgumentSpec]

    public init(content: String, arguments: [ArgumentSpec]) {
        self.content = content
        self.arguments = arguments
    }

    public func resolve(arguments suppliedArguments: [String: String]) throws -> String {
        let declaredByName = Dictionary(uniqueKeysWithValues: arguments.map { ($0.name, $0) })

        for spec in arguments where spec.required {
            if suppliedArguments[spec.name] == nil {
                throw PromptError.missingRequiredArgument(name: spec.name)
            }
        }

        var output = ""
        output.reserveCapacity(content.count)
        var cursor = content.startIndex

        while cursor < content.endIndex {
            guard let openIndex = content[cursor...].firstIndex(of: "{") else {
                output.append(contentsOf: content[cursor...])
                break
            }
            output.append(contentsOf: content[cursor..<openIndex])

            let afterOpen = content.index(after: openIndex)
            guard let closeIndex = content[afterOpen...].firstIndex(of: "}") else {
                // No closing brace — treat the rest as literal content.
                output.append(contentsOf: content[openIndex...])
                break
            }
            let placeholderName = String(content[afterOpen..<closeIndex])

            guard declaredByName[placeholderName] != nil else {
                throw PromptError.unknownPlaceholder(name: placeholderName)
            }

            if let value = suppliedArguments[placeholderName] {
                output.append(value)
            }
            // Optional placeholder with no supplied value collapses to empty.

            cursor = content.index(after: closeIndex)
        }

        return output
    }
}
