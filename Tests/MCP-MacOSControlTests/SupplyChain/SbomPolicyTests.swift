// STORY-021 — Software Supply Chain Security
//
// These tests don't validate the SBOM/SCA pipeline itself — that runs in
// GitHub Actions and is verified end-to-end on first PR. They validate
// that the policy artifacts the workflows depend on are committed,
// well-formed, and carry the values the workflows reference. Catching
// a missing license entry or a renamed key here fails fast at
// `swift test` time instead of after a CI round-trip.

import XCTest

final class SbomPolicyTests: XCTestCase {

    // MARK: - sbom-policy.yml

    func test_sbomPolicy_filePresentAndNonEmpty() throws {
        let url = repoRoot()
            .appendingPathComponent(".github")
            .appendingPathComponent("sbom-policy.yml")
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0, "sbom-policy.yml is empty")
    }

    func test_sbomPolicy_listsRequiredAllowedLicenses() throws {
        let content = try policyText("sbom-policy.yml")
        for license in ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC"] {
            XCTAssertTrue(
                content.contains(license),
                "sbom-policy.yml missing required allowed license: \(license)"
            )
        }
    }

    func test_sbomPolicy_declaresSeverityGates() throws {
        let content = try policyText("sbom-policy.yml")
        XCTAssertTrue(content.contains("block: critical"),
                      "Expected `block: critical` gate in sbom-policy.yml")
        XCTAssertTrue(content.contains("warn: high"),
                      "Expected `warn: high` gate in sbom-policy.yml")
        XCTAssertTrue(content.contains("medium") && content.contains("low"),
                      "Expected medium + low entries under `log:` in sbom-policy.yml")
    }

    // MARK: - dependabot.yml

    func test_dependabotConfig_presentAndCoversSwiftAndActions() throws {
        let content = try policyText("dependabot.yml")
        XCTAssertTrue(content.contains("package-ecosystem: \"swift\""),
                      "dependabot.yml missing swift ecosystem entry")
        XCTAssertTrue(content.contains("package-ecosystem: \"github-actions\""),
                      "dependabot.yml missing github-actions ecosystem entry")
    }

    // MARK: - vex-statements.json

    func test_vexStatements_filePresentAndValidJson() throws {
        let url = repoRoot()
            .appendingPathComponent(".github")
            .appendingPathComponent("vex-statements.json")
        let data = try Data(contentsOf: url)
        // Either a bare JSON array (current placeholder shape) or a
        // CycloneDX VEX document object — both are acceptable.
        let parsed = try JSONSerialization.jsonObject(with: data, options: [])
        let isArray = parsed is [Any]
        let isObject = parsed is [String: Any]
        XCTAssertTrue(isArray || isObject,
                      "vex-statements.json must parse as JSON array or object")
    }

    // MARK: - Helpers

    private func policyText(_ name: String) throws -> String {
        let url = repoRoot()
            .appendingPathComponent(".github")
            .appendingPathComponent(name)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Resolve the repository root from this test file's location. Using
    /// `#filePath` makes the tests independent of the working directory
    /// `swift test` was invoked from (Xcode, CLI, CI all differ).
    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // SupplyChain/
            .deletingLastPathComponent()  // MCP-MacOSControlTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // <repo root>
    }
}
