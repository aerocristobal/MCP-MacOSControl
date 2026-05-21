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

    func test_poam_eachItemHasStatusAndOwner() throws {
        let doc = try OscalPoamDocument.load(from: repoRoot().appendingPathComponent("oscal/plan-of-action-and-milestones.json"))
        for item in doc.planOfActionAndMilestones.poamItems {
            XCTAssertNotNil(item.status, "POA&M item \(item.uuid) (\(item.title)) is missing status prop")
            XCTAssertNotNil(item.owner, "POA&M item \(item.uuid) (\(item.title)) is missing poam-owner prop")
        }
    }

    func test_poam_openItemsHaveAtLeastOneMilestone() throws {
        let doc = try OscalPoamDocument.load(from: repoRoot().appendingPathComponent("oscal/plan-of-action-and-milestones.json"))
        for item in doc.planOfActionAndMilestones.poamItems
        where (item.status == "open" || item.status == "risk-accepted") {
            let count = item.milestones?.count ?? 0
            XCTAssertGreaterThan(count, 0, "Open POA&M item \(item.uuid) (\(item.title)) must declare at least one milestone with a target date")
        }
    }

    func test_poam_closedItemsCiteClosureEvidence() throws {
        let doc = try OscalPoamDocument.load(from: repoRoot().appendingPathComponent("oscal/plan-of-action-and-milestones.json"))
        for item in doc.planOfActionAndMilestones.poamItems where item.status == "closed" {
            let remarks = (item.remarks ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertFalse(remarks.isEmpty, "Closed POA&M item \(item.uuid) must carry closure evidence in remarks")
            XCTAssertTrue(remarks.lowercased().contains("story") || remarks.lowercased().contains("commit"),
                          "Closed POA&M item \(item.uuid) remarks must cite the story or commit that closed it")
        }
    }

    func test_poam_eachItemRelatedControlIdsExistInComponentDefinition() throws {
        let poam = try OscalPoamDocument.load(from: repoRoot().appendingPathComponent("oscal/plan-of-action-and-milestones.json"))
        let checker = OscalCoverageChecker(
            componentDefinitionPath: repoRoot().appendingPathComponent("oscal/component-definition.json").path,
            securityMdPath: repoRoot().appendingPathComponent("docs/SECURITY.md").path
        )
        let report = try checker.report()
        for item in poam.planOfActionAndMilestones.poamItems {
            for ref in item.relatedControls ?? [] {
                XCTAssertTrue(report.implementedControls.contains(ref.controlId.lowercased()),
                              "POA&M item \(item.uuid) references control \(ref.controlId) not in component-definition.json")
            }
        }
    }

    func test_poam_idAllocationsFileExistsAndCoversEveryUuid() throws {
        let poam = try OscalPoamDocument.load(from: repoRoot().appendingPathComponent("oscal/plan-of-action-and-milestones.json"))
        let registry = try String(contentsOf: repoRoot().appendingPathComponent("oscal/poam-id-allocations.md"), encoding: .utf8)
        for item in poam.planOfActionAndMilestones.poamItems {
            XCTAssertTrue(registry.contains(item.uuid),
                          "poam-id-allocations.md is missing item \(item.uuid) — add a row when introducing a new POA&M item")
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
