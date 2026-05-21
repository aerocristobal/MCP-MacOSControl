// FILE: Tests/MCP-MacOSControlTests/Compliance/PoamCoverageCheckerTests.swift
// STORY: STORY-037 — OSCAL Assessment Results & POA&M Artifacts
// COMPONENT: PoamCoverageChecker
//
// Covers BDD scenarios:
//   "Each accepted-risk statement in SECURITY.md §4 has a corresponding POA&M item"
//   "POA&M items closed by Sprint 6 hardening are marked closed with evidence"
//   "PR that adds a SECURITY.md §4 accepted-risk statement requires a POA&M entry"
//   "PR that closes a §4 accepted-risk statement requires the POA&M status to flip"

import XCTest
@testable import OSCALComplianceSupport

final class PoamCoverageCheckerTests: XCTestCase {

    private func repoRoot() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    // MARK: - Committed-artifact integration

    func test_committedSecurityMdAndPoamAreInSync() throws {
        let report = try PoamCoverageChecker().report(
            securityMdPath: repoRoot().appendingPathComponent("docs/SECURITY.md").path,
            poamPath: repoRoot().appendingPathComponent("oscal/plan-of-action-and-milestones.json").path
        )
        XCTAssertTrue(
            report.missingSections.isEmpty,
            "section4_poam_drift — accepted-risk statements without a matching open POA&M item: \(report.missingSections.sorted())"
        )
        XCTAssertTrue(
            report.extraSections.isEmpty,
            "section4_poam_drift — POA&M items reference §4 subsections that don't exist in SECURITY.md: \(report.extraSections.sorted())"
        )
        XCTAssertTrue(
            report.openItemsForClosedSections.isEmpty,
            "section4_poam_drift — POA&M items still open after their §4 statement was removed: \(report.openItemsForClosedSections)"
        )
        XCTAssertTrue(
            report.closedItemsLackingEvidence.isEmpty,
            "section4_poam_drift — closed items must carry remarks with closure evidence: \(report.closedItemsLackingEvidence)"
        )
    }

    // MARK: - Synthetic-fixture cases

    private func makeItem(uuid: String, section: String?, status: String, remarks: String? = nil) -> OscalPoamItem {
        var props: [OscalProp] = [OscalProp(name: "status", value: status)]
        if let s = section { props.append(OscalProp(name: "security-md-section", value: s)) }
        return OscalPoamItem(
            uuid: uuid,
            title: "test item",
            description: "test",
            props: props,
            remarks: remarks
        )
    }

    private func makePoam(items: [OscalPoamItem]) -> OscalPoamDocument {
        OscalPoamDocument(planOfActionAndMilestones: OscalPoamBody(
            uuid: "00000000-0000-0000-0000-0000000000aa",
            metadata: OscalMetadata(title: "T", lastModified: "2026-01-01T00:00:00.000Z", version: "1.0.0", oscalVersion: "1.1.2"),
            importSsp: nil,
            systemId: OscalPoamSystemId(id: "mcp-macos-control", identifierType: "https://ietf.org/rfc/rfc4122"),
            poamItems: items
        ))
    }

    func test_coverage_passesWhenEverySection4StatementHasOpenPoamItem() {
        let md = """
        ## 4. Threat Catalog
        ### 4.1 regex bypass
        **Accepted residual risk.** Detail.
        ### 4.4 sink
        **Acknowledged residual risk.** Detail.
        """
        let poam = makePoam(items: [
            makeItem(uuid: "u-41", section: "4.1", status: "risk-accepted"),
            makeItem(uuid: "u-44", section: "4.4", status: "risk-accepted")
        ])
        let r = PoamCoverageChecker.report(securityMd: md, poam: poam)
        XCTAssertTrue(r.missingSections.isEmpty)
        XCTAssertTrue(r.extraSections.isEmpty)
        XCTAssertEqual(r.coveredSections, Set(["4.1", "4.4"]))
    }

    func test_coverage_failsAndReportsMissingItem() {
        let md = """
        ## 4. Threat Catalog
        ### 4.1 regex bypass
        **Accepted residual risk.** Detail.
        ### 4.5 a new risk added today
        **Accepted residual risk.** Detail.
        """
        let poam = makePoam(items: [
            makeItem(uuid: "u-41", section: "4.1", status: "risk-accepted")
        ])
        let r = PoamCoverageChecker.report(securityMd: md, poam: poam)
        XCTAssertEqual(r.missingSections, Set(["4.5"]))
    }

    func test_coverage_failsAndReportsExtraItem() {
        let md = """
        ## 4. Threat Catalog
        ### 4.1 regex bypass
        **Accepted residual risk.** Detail.
        """
        let poam = makePoam(items: [
            makeItem(uuid: "u-41", section: "4.1", status: "risk-accepted"),
            makeItem(uuid: "u-99", section: "4.99", status: "risk-accepted")
        ])
        let r = PoamCoverageChecker.report(securityMd: md, poam: poam)
        XCTAssertEqual(r.extraSections, Set(["4.99"]))
    }

    func test_coverage_failsWhenSection4RemovedButItemStillOpen() {
        let md = """
        ## 4. Threat Catalog
        ### 4.1 regex bypass
        **Accepted residual risk.** Detail.
        """
        let poam = makePoam(items: [
            makeItem(uuid: "u-41", section: "4.1", status: "risk-accepted"),
            // §4.4 was removed from SECURITY.md, but this item is still open — must flip.
            makeItem(uuid: "u-44", section: "4.4", status: "open")
        ])
        let r = PoamCoverageChecker.report(securityMd: md, poam: poam)
        XCTAssertTrue(r.openItemsForClosedSections.contains("u-44"))
    }

    func test_coverage_closedItemSatisfiesCoverageOnlyWithEvidenceRemarks() {
        // A closed item without remarks → flagged.
        let md = """
        ## 4. Threat Catalog
        ### 4.1 regex bypass
        **Accepted residual risk.** Detail.
        """
        let poam = makePoam(items: [
            makeItem(uuid: "u-41", section: "4.1", status: "risk-accepted"),
            makeItem(uuid: "u-historical", section: nil, status: "closed", remarks: "  ")
        ])
        let r = PoamCoverageChecker.report(securityMd: md, poam: poam)
        XCTAssertTrue(r.closedItemsLackingEvidence.contains("u-historical"))
    }

    func test_coverage_closedItemWithEvidenceRemarksPasses() {
        let md = """
        ## 4. Threat Catalog
        ### 4.1 regex bypass
        **Accepted residual risk.** Detail.
        """
        let poam = makePoam(items: [
            makeItem(uuid: "u-41", section: "4.1", status: "risk-accepted"),
            makeItem(uuid: "u-historical", section: nil, status: "closed", remarks: "Closed by STORY-024 — evidence in docs/AUDIT-LOG-OPERATIONS.md.")
        ])
        let r = PoamCoverageChecker.report(securityMd: md, poam: poam)
        XCTAssertTrue(r.closedItemsLackingEvidence.isEmpty)
    }

    func test_coverage_closedItemDoesNotSatisfyOpenCoverageRequirement() {
        // §4.5 has only a closed item — closure doesn't satisfy "open coverage"
        // because the §4 statement still claims an accepted risk.
        let md = """
        ## 4. Threat Catalog
        ### 4.1 regex bypass
        **Accepted residual risk.** Detail.
        ### 4.5 another active risk
        **Accepted residual risk.** Detail.
        """
        let poam = makePoam(items: [
            makeItem(uuid: "u-41", section: "4.1", status: "risk-accepted"),
            makeItem(uuid: "u-45", section: "4.5", status: "closed", remarks: "Closed by ...")
        ])
        let r = PoamCoverageChecker.report(securityMd: md, poam: poam)
        XCTAssertTrue(r.missingSections.contains("4.5"),
                      "A closed item must not satisfy coverage while §4 still declares the risk accepted")
    }
}
