// STORY: STORY-016 — Structured Error Response Contract
// COMPONENT: grep-audit — no ad-hoc error construction may remain in Sources/

import XCTest

final class NoAdhocErrorConstructionAuditTests: XCTestCase {

    private static func sourcesRoot(file: String = #file) -> URL {
        URL(fileURLWithPath: file)
            .deletingLastPathComponent()  // StructuredErrors/
            .deletingLastPathComponent()  // MCP-MacOSControlTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // <root>/
            .appendingPathComponent("Sources", isDirectory: true)
    }

    private func swiftFiles(under url: URL) throws -> [URL] {
        var out: [URL] = []
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return [] }
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "swift" { out.append(fileURL) }
        }
        return out
    }

    func test_noAdhocErrorTextConstructionExists() throws {
        let root = Self.sourcesRoot()
        let files = try swiftFiles(under: root)
        XCTAssertFalse(files.isEmpty, "no Swift sources found under \(root.path)")

        // Files we are allowed to construct error results inline (the central
        // builder lives here by design — every other site must route through it).
        let permittedFile = "MCPErrorResponseBuilder.swift"

        var offenders: [String] = []
        for file in files where file.lastPathComponent != permittedFile {
            let text = try String(contentsOf: file, encoding: .utf8)
            // ad-hoc plain-text error construction patterns
            if text.contains(".text(\"Error: ") {
                offenders.append("\(file.lastPathComponent): contains `.text(\"Error: ...\"`")
            }
            if text.contains(".text(\"Invalid parameters: ") {
                offenders.append("\(file.lastPathComponent): contains `.text(\"Invalid parameters: ...\"`")
            }
            // Bare construction of .init(content: [...], isError: true) outside the
            // builder is the precise pattern STORY-016 eliminates.
            if text.contains("isError: true") {
                // Allow it ONLY if every occurrence is part of a builder call chain.
                let lines = text.components(separatedBy: "\n")
                for (idx, line) in lines.enumerated() where line.contains("isError: true") {
                    // Heuristic: if the line is part of `.init(content:` we still
                    // consider it an offender. Routing through MCPErrorResponseBuilder
                    // does not contain `isError: true` literal.
                    if line.contains(".init(content:") {
                        offenders.append("\(file.lastPathComponent):\(idx + 1): `\(line.trimmingCharacters(in: .whitespaces))`")
                    }
                }
            }
        }

        XCTAssertTrue(offenders.isEmpty,
                      "STORY-016: ad-hoc error response construction must be eliminated. Offenders:\n  - " +
                      offenders.joined(separator: "\n  - "))
    }
}
