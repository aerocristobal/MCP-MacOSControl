// FILE: Tests/MCP-MacOSControlTests/Compliance/SecurityMdSection4ExtractorTests.swift
// STORY: STORY-037 — OSCAL Assessment Results & POA&M Artifacts
// COMPONENT: SecurityMdSection4Extractor
//
// Covers the BDD step "Given SECURITY.md §4 contains accepted-risk
// statements (e.g., §4.1 regex bypass classes, §4.4 deferred production
// audit sink before STORY-024 ships)".

import XCTest
@testable import OSCALComplianceSupport

final class SecurityMdSection4ExtractorTests: XCTestCase {

    private let extractor = SecurityMdSection4Extractor()

    func test_extractor_findsBoldedAcceptedResidualRisk() {
        let md = """
        ## 4. Threat Catalog

        ### 4.1 Regex bypass classes

        **Threat.** Some text.

        **Accepted residual risk.** Body of the risk.

        ### 4.2 Single-secret exfiltration

        **Threat.** Some text.

        **Accepted residual risk.** Body of the risk.
        """
        let result = extractor.extract(from: md)
        XCTAssertEqual(result.map { $0.section }, ["4.1", "4.2"])
    }

    func test_extractor_acceptsAcknowledgedResidualRiskVariant() {
        let md = """
        ## 4. Threat Catalog

        ### 4.4 Audit log tampering

        **Acknowledged residual risk.** A per-record digital signature would be stronger...
        """
        let result = extractor.extract(from: md)
        XCTAssertEqual(result.first?.section, "4.4")
    }

    func test_extractor_ignoresUnrelatedTopLevelSections() {
        let md = """
        ## 3. Some other section

        ### 3.1 Subsection

        **Accepted residual risk.** This should be ignored — not in §4.

        ## 4. Threat Catalog

        ### 4.1 Actual risk

        **Accepted residual risk.** This one counts.
        """
        let result = extractor.extract(from: md)
        XCTAssertEqual(result.map { $0.section }, ["4.1"])
    }

    func test_extractor_returnsEmptyWhenNoSection4() {
        let md = """
        ## 5. Some unrelated section

        ### 5.1 Subsection

        **Accepted residual risk.** Irrelevant.
        """
        let result = extractor.extract(from: md)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Live SECURITY.md

    func test_extractor_findsSection4StatementsInCommittedSecurityMd() throws {
        let path = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/SECURITY.md").path
        let md = try String(contentsOfFile: path, encoding: .utf8)
        let result = extractor.extract(from: md)
        let sections = Set(result.map { $0.section })
        XCTAssertTrue(sections.contains("4.1"), "extractor must find §4.1 (regex bypass) in committed SECURITY.md")
        XCTAssertTrue(sections.contains("4.4"), "extractor must find §4.4 (audit log tampering) in committed SECURITY.md")
    }
}
