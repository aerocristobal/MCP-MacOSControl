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
            "section4_poam_drift — accepted-risk statements without a matching open-like risk: \(report.missingSections.sorted())"
        )
        XCTAssertTrue(
            report.extraSections.isEmpty,
            "section4_poam_drift — risks reference §4 subsections that don't exist in SECURITY.md: \(report.extraSections.sorted())"
        )
        XCTAssertTrue(
            report.openRisksForClosedSections.isEmpty,
            "section4_poam_drift — risks still open-like after their §4 statement was removed: \(report.openRisksForClosedSections)"
        )
        XCTAssertTrue(
            report.closedRisksLackingEvidence.isEmpty,
            "section4_poam_drift — closed risks must cite closure evidence in risk-log: \(report.closedRisksLackingEvidence)"
        )
    }

    // MARK: - Synthetic-fixture cases

    private func makeRisk(uuid: String, section: String?, status: String, riskLogDescription: String? = nil) -> OscalRisk {
        var props: [OscalProp] = [OscalProp(name: "poam-owner", value: "security-owner")]
        if let s = section { props.append(OscalProp(name: "security-md-section", value: s)) }
        let log: OscalRiskLog?
        if let d = riskLogDescription {
            log = OscalRiskLog(entries: [
                OscalRiskLogEntry(uuid: uuid + "-log", title: "log", description: d, start: "2026-05-21T00:00:00.000Z", statusChange: status)
            ])
        } else {
            log = nil
        }
        return OscalRisk(
            uuid: uuid,
            title: "test risk",
            description: "test",
            statement: "test",
            status: status,
            props: props,
            riskLog: log
        )
    }

    private func makePoam(risks: [OscalRisk]) -> OscalPoamDocument {
        OscalPoamDocument(planOfActionAndMilestones: OscalPoamBody(
            uuid: "55555555-0000-4000-8000-0000000000aa",
            metadata: OscalMetadata(title: "T", lastModified: "2026-01-01T00:00:00.000Z", version: "1.0.0", oscalVersion: "1.1.2"),
            importSsp: nil,
            systemId: OscalPoamSystemId(id: "mcp-macos-control", identifierType: "https://ietf.org/rfc/rfc4122"),
            risks: risks,
            poamItems: risks.map { r in
                OscalPoamItem(title: "track " + r.uuid, description: "track", relatedRisks: [OscalPoamRelatedRisk(riskUuid: r.uuid)])
            }
        ))
    }

    func test_coverage_passesWhenEverySection4StatementHasOpenLikeRisk() {
        let md = """
        ## 4. Threat Catalog
        ### 4.1 regex bypass
        **Accepted residual risk.** Detail.
        ### 4.4 sink
        **Acknowledged residual risk.** Detail.
        """
        let poam = makePoam(risks: [
            makeRisk(uuid: "u-41", section: "4.1", status: "deviation-approved"),
            makeRisk(uuid: "u-44", section: "4.4", status: "deviation-approved")
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
        let poam = makePoam(risks: [
            makeRisk(uuid: "u-41", section: "4.1", status: "deviation-approved")
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
        let poam = makePoam(risks: [
            makeRisk(uuid: "u-41", section: "4.1", status: "deviation-approved"),
            makeRisk(uuid: "u-99", section: "4.99", status: "deviation-approved")
        ])
        let r = PoamCoverageChecker.report(securityMd: md, poam: poam)
        XCTAssertEqual(r.extraSections, Set(["4.99"]))
    }

    func test_coverage_failsWhenSection4RemovedButRiskStillOpen() {
        let md = """
        ## 4. Threat Catalog
        ### 4.1 regex bypass
        **Accepted residual risk.** Detail.
        """
        let poam = makePoam(risks: [
            makeRisk(uuid: "u-41", section: "4.1", status: "deviation-approved"),
            // §4.4 was removed from SECURITY.md, but this risk is still open — must flip.
            makeRisk(uuid: "u-44", section: "4.4", status: "open")
        ])
        let r = PoamCoverageChecker.report(securityMd: md, poam: poam)
        XCTAssertTrue(r.openRisksForClosedSections.contains("u-44"))
    }

    func test_coverage_closedRiskWithoutLogEvidenceIsFlagged() {
        let md = """
        ## 4. Threat Catalog
        ### 4.1 regex bypass
        **Accepted residual risk.** Detail.
        """
        let poam = makePoam(risks: [
            makeRisk(uuid: "u-41", section: "4.1", status: "deviation-approved"),
            // Closed but no log entry → must be flagged.
            makeRisk(uuid: "u-historical", section: nil, status: "closed", riskLogDescription: nil)
        ])
        let r = PoamCoverageChecker.report(securityMd: md, poam: poam)
        XCTAssertTrue(r.closedRisksLackingEvidence.contains("u-historical"))
    }

    func test_coverage_closedRiskWithEvidenceLogPasses() {
        let md = """
        ## 4. Threat Catalog
        ### 4.1 regex bypass
        **Accepted residual risk.** Detail.
        """
        let poam = makePoam(risks: [
            makeRisk(uuid: "u-41", section: "4.1", status: "deviation-approved"),
            makeRisk(uuid: "u-historical", section: nil, status: "closed", riskLogDescription: "Closed by STORY-024 — evidence in docs/AUDIT-LOG-OPERATIONS.md.")
        ])
        let r = PoamCoverageChecker.report(securityMd: md, poam: poam)
        XCTAssertTrue(r.closedRisksLackingEvidence.isEmpty)
    }

    func test_coverage_closedRiskDoesNotSatisfyOpenCoverageRequirement() {
        let md = """
        ## 4. Threat Catalog
        ### 4.1 regex bypass
        **Accepted residual risk.** Detail.
        ### 4.5 another active risk
        **Accepted residual risk.** Detail.
        """
        let poam = makePoam(risks: [
            makeRisk(uuid: "u-41", section: "4.1", status: "deviation-approved"),
            makeRisk(uuid: "u-45", section: "4.5", status: "closed", riskLogDescription: "Closed by ...")
        ])
        let r = PoamCoverageChecker.report(securityMd: md, poam: poam)
        XCTAssertTrue(r.missingSections.contains("4.5"),
                      "A closed risk must not satisfy coverage while §4 still declares the risk accepted")
    }
}
