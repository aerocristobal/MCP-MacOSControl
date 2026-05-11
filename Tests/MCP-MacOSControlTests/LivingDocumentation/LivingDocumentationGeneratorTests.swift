// Generates docs/LIVING-DOCUMENTATION.md by parsing the project's .feature
// files and joining each scenario title against LivingDocumentationMapping.
// Scenarios without a mapping fail the build, so adding a new scenario without
// an executable proof is caught at swift-test time.

import XCTest

final class LivingDocumentationGeneratorTests: XCTestCase {

    // MARK: - Test entrypoint

    func test_writesLivingDocumentation_andEveryScenarioHasMappedTests() throws {
        let root = Self.projectRoot()
        let featuresDir = root.appendingPathComponent("Tests/MCP-MacOSControlTests/Features", isDirectory: true)
        let outputFile = root.appendingPathComponent("docs/LIVING-DOCUMENTATION.md")

        let featureURLs = try FileManager.default
            .contentsOfDirectory(at: featuresDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "feature" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        XCTAssertFalse(featureURLs.isEmpty, "no .feature files found at \(featuresDir.path)")

        var unmapped: [(file: String, scenario: String)] = []
        var sections: [String] = []

        for url in featureURLs {
            let parsed = try Self.parseFeature(at: url)
            sections.append(Self.render(feature: parsed,
                                        mapping: LivingDocumentationMapping.scenarioToTests,
                                        unmapped: &unmapped))
        }

        let document = Self.header() + sections.joined()

        try FileManager.default.createDirectory(at: outputFile.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try document.write(to: outputFile, atomically: true, encoding: .utf8)

        if !unmapped.isEmpty {
            let lines = unmapped
                .map { "  - \($0.file): \"\($0.scenario)\"" }
                .joined(separator: "\n")
            XCTFail("""
            Living documentation found scenarios with no mapped unit test. Add an entry to \
            Tests/MCP-MacOSControlTests/LivingDocumentation/LivingDocumentationMapping.swift \
            for each:
            \(lines)
            """)
        }
    }

    // MARK: - Path resolution

    private static func projectRoot(file: String = #file) -> URL {
        // file ≈ <root>/Tests/MCP-MacOSControlTests/LivingDocumentation/LivingDocumentationGeneratorTests.swift
        URL(fileURLWithPath: file)
            .deletingLastPathComponent()  // LivingDocumentation/
            .deletingLastPathComponent()  // MCP-MacOSControlTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // <root>/
    }

    // MARK: - Feature parsing

    fileprivate struct ParsedFeature {
        let filename: String
        let title: String
        let descriptionLines: [String]
        let scenarios: [Scenario]
    }

    fileprivate struct Scenario {
        let title: String
        let kind: Kind
        enum Kind: String { case scenario = "Scenario", outline = "Scenario Outline" }
    }

    private static func parseFeature(at url: URL) throws -> ParsedFeature {
        let contents = try String(contentsOf: url, encoding: .utf8)
        var title = ""
        var descLines: [String] = []
        var scenarios: [Scenario] = []
        var inDescription = false

        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("Feature:") {
                title = String(line.dropFirst("Feature:".count)).trimmingCharacters(in: .whitespaces)
                inDescription = true
                continue
            }
            // Order matters: "Scenario Outline:" must be checked before "Scenario:".
            if line.hasPrefix("Scenario Outline:") {
                let s = String(line.dropFirst("Scenario Outline:".count)).trimmingCharacters(in: .whitespaces)
                scenarios.append(Scenario(title: s, kind: .outline))
                inDescription = false
                continue
            }
            if line.hasPrefix("Scenario:") {
                let s = String(line.dropFirst("Scenario:".count)).trimmingCharacters(in: .whitespaces)
                scenarios.append(Scenario(title: s, kind: .scenario))
                inDescription = false
                continue
            }
            if line.hasPrefix("Background:") || line.hasPrefix("Examples:") || line.hasPrefix("@") {
                inDescription = false
                continue
            }
            if inDescription, !line.isEmpty {
                descLines.append(line)
            }
        }

        return ParsedFeature(
            filename: url.lastPathComponent,
            title: title,
            descriptionLines: descLines,
            scenarios: scenarios
        )
    }

    // MARK: - Markdown rendering

    private static func header() -> String {
        """
        # Living Documentation

        > Generated by `LivingDocumentationGeneratorTests`. Do not edit by hand.
        > Run `swift test --filter LivingDocumentationGeneratorTests` to regenerate.

        Each scenario in the project's `.feature` files is listed alongside the
        unit tests that prove its behavior. Run `swift test` to verify all mapped
        tests pass; the generator itself fails the build if any scenario lacks a
        mapped test.

        """
    }

    fileprivate static func render(feature: ParsedFeature,
                                   mapping: [String: [String]],
                                   unmapped: inout [(file: String, scenario: String)]) -> String {
        var md = "\n## \(feature.title)\n\n"
        md += "*Source: `Tests/MCP-MacOSControlTests/Features/\(feature.filename)`*\n\n"

        for line in feature.descriptionLines {
            md += "> \(line)\n"
        }
        if !feature.descriptionLines.isEmpty { md += "\n" }

        for scenario in feature.scenarios {
            md += "### \(scenario.kind.rawValue): \(scenario.title)\n\n"
            if let tests = mapping[scenario.title], !tests.isEmpty {
                for test in tests {
                    md += "- `\(test)`\n"
                }
            } else {
                unmapped.append((file: feature.filename, scenario: scenario.title))
                md += "- _**No mapped test — update LivingDocumentationMapping.swift.**_\n"
            }
            md += "\n"
        }

        return md
    }
}
