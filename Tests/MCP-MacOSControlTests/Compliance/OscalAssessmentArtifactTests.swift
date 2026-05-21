// FILE: Tests/MCP-MacOSControlTests/Compliance/OscalAssessmentArtifactTests.swift
// STORY: STORY-037 — OSCAL Assessment Results & POA&M Artifacts
//
// Structural tests for the committed POA&M and Assessment Results
// artifacts. The NIST OSCAL CLI is the schema authority (called by CI);
// these tests cover the project-specific invariants the CLI cannot:
//
//   * Required OSCAL model version on metadata.
//   * Every poam-item has status + owner + (where applicable) §4 link.
//   * Every observation references at least one control link.
//   * UUIDs are valid v4 shape.
//   * README links exist and name the OSCAL model version of each artifact.

import XCTest
@testable import OSCALComplianceSupport

final class OscalAssessmentArtifactTests: XCTestCase {

    private func repoRoot() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    // MARK: - POA&M

    func test_poam_isReadableAndDeclaresOscalVersion112OrLater() throws {
        let doc = try OscalPoamDocument.load(from: repoRoot().appendingPathComponent("oscal/plan-of-action-and-milestones.json"))
        XCTAssertEqual(doc.planOfActionAndMilestones.metadata.oscalVersion.split(separator: ".").prefix(2).joined(separator: "."), "1.1",
                       "POA&M must declare OSCAL 1.1.x")
    }

    func test_poam_eachRiskHasStatusAndOwner() throws {
        let doc = try OscalPoamDocument.load(from: repoRoot().appendingPathComponent("oscal/plan-of-action-and-milestones.json"))
        for risk in doc.risks {
            XCTAssertFalse(risk.status.isEmpty, "Risk \(risk.uuid) (\(risk.title)) is missing status")
            XCTAssertNotNil(risk.owner, "Risk \(risk.uuid) (\(risk.title)) is missing poam-owner prop")
        }
    }

    func test_poam_openRisksTiedToSection4HaveAtLeastOneMilestone() throws {
        // BDD §2 "POA&M includes the milestone schedule for each open
        // item" specifies milestones for §4-derived risks. Auto-opened
        // operational risks (e.g. the chain-break risk) carry action
        // tasks instead of milestones — actions are remediations, not
        // forward-planned dates. Distinguish via security-md-section.
        let doc = try OscalPoamDocument.load(from: repoRoot().appendingPathComponent("oscal/plan-of-action-and-milestones.json"))
        for risk in doc.risks
        where PoamCoverageChecker.openLikeStatuses.contains(risk.status) && risk.securityMdSection != nil {
            let milestones = risk.milestones
            XCTAssertGreaterThan(milestones.count, 0, "§4-derived open risk \(risk.uuid) (\(risk.title)) must declare at least one milestone with a target date")
            for m in milestones {
                XCTAssertNotNil(m.targetDate, "Milestone \(m.uuid) under \(risk.title) must declare a target-date (timing.on-date.date)")
            }
        }
    }

    func test_poam_openRisksAllHaveAtLeastOneTask() throws {
        // The auto-opened chain-break risk is open-like and exempt from
        // the "milestone" requirement above, but it must still carry a
        // remediation task (action or milestone) so an assessor can see
        // what response is planned.
        let doc = try OscalPoamDocument.load(from: repoRoot().appendingPathComponent("oscal/plan-of-action-and-milestones.json"))
        for risk in doc.risks where PoamCoverageChecker.openLikeStatuses.contains(risk.status) {
            let taskCount = (risk.remediations ?? []).reduce(0) { acc, r in acc + (r.tasks?.count ?? 0) }
            XCTAssertGreaterThan(taskCount, 0, "Open-like Risk \(risk.uuid) (\(risk.title)) must declare at least one remediation task")
        }
    }

    func test_poam_closedRisksCiteClosureEvidenceInRiskLog() throws {
        let doc = try OscalPoamDocument.load(from: repoRoot().appendingPathComponent("oscal/plan-of-action-and-milestones.json"))
        for risk in doc.risks where risk.status == "closed" {
            let entries = risk.riskLog?.entries ?? []
            XCTAssertFalse(entries.isEmpty, "Closed Risk \(risk.uuid) must carry at least one risk-log entry")
            let lowered = entries.compactMap { $0.description?.lowercased() }.joined(separator: " ")
            XCTAssertTrue(lowered.contains("story") || lowered.contains("commit") || lowered.contains("evidence"),
                          "Closed Risk \(risk.uuid) risk-log must cite the story / commit / evidence that closed it")
        }
    }

    func test_poam_eachRiskRelatedControlLinkExistsInComponentDefinition() throws {
        let poam = try OscalPoamDocument.load(from: repoRoot().appendingPathComponent("oscal/plan-of-action-and-milestones.json"))
        let checker = OscalCoverageChecker(
            componentDefinitionPath: repoRoot().appendingPathComponent("oscal/component-definition.json").path,
            securityMdPath: repoRoot().appendingPathComponent("docs/SECURITY.md").path
        )
        let report = try checker.report()
        for risk in poam.risks {
            for link in (risk.links ?? []) where link.rel == "related" && link.href.hasPrefix("#") {
                let controlId = String(link.href.dropFirst()).lowercased()
                XCTAssertTrue(report.implementedControls.contains(controlId),
                              "Risk \(risk.uuid) links to control \(controlId) not in component-definition.json")
            }
        }
    }

    func test_poam_idAllocationsFileExistsAndCoversEveryRiskAndPoamItemUuid() throws {
        let poam = try OscalPoamDocument.load(from: repoRoot().appendingPathComponent("oscal/plan-of-action-and-milestones.json"))
        let registry = try String(contentsOf: repoRoot().appendingPathComponent("oscal/poam-id-allocations.md"), encoding: .utf8)
        for risk in poam.risks {
            XCTAssertTrue(registry.contains(risk.uuid),
                          "poam-id-allocations.md is missing risk \(risk.uuid) — add a row when introducing a new risk")
        }
        for item in poam.poamItems {
            if let uuid = item.uuid {
                XCTAssertTrue(registry.contains(uuid),
                              "poam-id-allocations.md is missing poam-item \(uuid) — add a row when introducing a new poam-item")
            }
        }
    }

    func test_poam_poamItemsReferenceExistingRiskUuids() throws {
        let poam = try OscalPoamDocument.load(from: repoRoot().appendingPathComponent("oscal/plan-of-action-and-milestones.json"))
        let riskUuids = Set(poam.risks.map { $0.uuid.lowercased() })
        for item in poam.poamItems {
            for ref in item.relatedRisks ?? [] {
                XCTAssertTrue(riskUuids.contains(ref.riskUuid.lowercased()),
                              "POA&M item \(item.uuid ?? item.title) references risk \(ref.riskUuid) which is not in risks[]")
            }
        }
    }

    // MARK: - Assessment Results

    func test_assessmentResults_isReadableAndDeclaresOscalVersion112() throws {
        let doc = try OscalAssessmentResultsDocument.load(from: repoRoot().appendingPathComponent("oscal/assessment-results.json"))
        XCTAssertEqual(doc.assessmentResults.metadata.oscalVersion.split(separator: ".").prefix(2).joined(separator: "."), "1.1",
                       "Assessment Results must declare OSCAL 1.1.x")
    }

    func test_assessmentResults_seedHasObservations() throws {
        let doc = try OscalAssessmentResultsDocument.load(from: repoRoot().appendingPathComponent("oscal/assessment-results.json"))
        XCTAssertFalse(doc.observations.isEmpty, "Committed AR must be non-empty (seeded by oscal-emit on the fixture)")
    }

    func test_assessmentResults_everyObservationHasAtLeastOneControlLink() throws {
        let doc = try OscalAssessmentResultsDocument.load(from: repoRoot().appendingPathComponent("oscal/assessment-results.json"))
        for obs in doc.observations {
            let controls = (obs.links ?? []).filter { $0.rel == "control" }
            XCTAssertFalse(controls.isEmpty, "Observation \(obs.uuid) (\(obs.title)) has no control link — assessor cannot roll it up into a finding")
        }
    }

    func test_assessmentResults_uuidsAreV4Shape() throws {
        let doc = try OscalAssessmentResultsDocument.load(from: repoRoot().appendingPathComponent("oscal/assessment-results.json"))
        let uuidRegex = try NSRegularExpression(
            pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
        )
        for obs in doc.observations {
            let range = NSRange(obs.uuid.startIndex..<obs.uuid.endIndex, in: obs.uuid)
            XCTAssertNotNil(uuidRegex.firstMatch(in: obs.uuid, range: range),
                            "Observation \(obs.uuid) is not a valid v4-shape UUID")
        }
    }

    func test_assessmentResults_mappingDocReferencesEveryKnownEventType() throws {
        let md = try String(contentsOf: repoRoot().appendingPathComponent("oscal/assessment-results-mapping.md"), encoding: .utf8)
        // Every AuditEventType raw value must appear in the mapping doc.
        for eventType in EventTypeMapping().knownEventTypes {
            XCTAssertTrue(md.contains(eventType.rawValue),
                          "assessment-results-mapping.md does not mention AuditEventType.\(eventType.rawValue)")
        }
    }

    // MARK: - README discoverability

    func test_readme_linksAllThreeOscalArtifacts() throws {
        let readme = try String(contentsOf: repoRoot().appendingPathComponent("README.md"), encoding: .utf8)
        XCTAssertTrue(readme.contains("oscal/component-definition.json"),
                      "README must link oscal/component-definition.json")
        XCTAssertTrue(readme.contains("oscal/plan-of-action-and-milestones.json"),
                      "README must link oscal/plan-of-action-and-milestones.json")
        XCTAssertTrue(readme.contains("oscal/assessment-results.json"),
                      "README must link oscal/assessment-results.json")
    }

    func test_readme_namesOscalModelVersionForEachArtifact() throws {
        let readme = try String(contentsOf: repoRoot().appendingPathComponent("README.md"), encoding: .utf8)
        // Cheap heuristic: the OSCAL version string must appear at least
        // three times — once per artifact — under the Compliance section.
        let occurrences = readme.components(separatedBy: "OSCAL 1.1.2").count - 1
        XCTAssertGreaterThanOrEqual(occurrences, 3, "README must name the OSCAL model version next to each artifact link")
    }
}
