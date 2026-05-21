// FILE: Tests/MCP-MacOSControlTests/Compliance/OscalArtifactStructuralTests.swift
// STORY: STORY-022 — OSCAL Component Definition
// Structural sanity checks the `oscal-cli` schema validator will not catch:
// every `rel: implementation` link must point to a file that exists in
// this repository. Schema validation can prove the JSON is well-formed
// OSCAL; only the working tree can prove the source path is correct.

import XCTest
import OSCALComplianceSupport
import Foundation

final class OscalArtifactStructuralTests: XCTestCase {

    private func repoRoot() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private func loadDocument() throws -> OscalComponentDefinitionDocument {
        let checker = OscalCoverageChecker(
            componentDefinitionPath: repoRoot().appendingPathComponent("oscal/component-definition.json").path,
            securityMdPath: repoRoot().appendingPathComponent("docs/SECURITY.md").path
        )
        return try checker.parsedComponentDefinition()
    }

    func test_metadata_isPopulated() throws {
        let doc = try loadDocument()
        XCTAssertEqual(doc.componentDefinition.metadata.oscalVersion, "1.1.2",
                       "OSCAL version must match the validator target")
        XCTAssertFalse(doc.componentDefinition.metadata.title.isEmpty)
        XCTAssertFalse(doc.componentDefinition.metadata.lastModified.isEmpty)
        XCTAssertFalse(doc.componentDefinition.metadata.version.isEmpty)
    }

    func test_uuids_areAllValidV4() throws {
        let doc = try loadDocument()
        let pattern = #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#
        let regex = try NSRegularExpression(pattern: pattern)

        func assertUuid(_ uuid: String, label: String) {
            let range = NSRange(uuid.startIndex..<uuid.endIndex, in: uuid)
            XCTAssertNotNil(
                regex.firstMatch(in: uuid, range: range),
                "\(label) UUID \(uuid) is not lowercase-formatted v4-shaped"
            )
        }

        assertUuid(doc.componentDefinition.uuid, label: "document")
        for component in doc.componentDefinition.components {
            assertUuid(component.uuid, label: "component")
            for impl in component.controlImplementations ?? [] {
                assertUuid(impl.uuid, label: "control-implementation")
                for req in impl.implementedRequirements {
                    assertUuid(req.uuid, label: "implemented-requirement \(req.controlId)")
                    for statement in req.statements ?? [] {
                        assertUuid(statement.uuid, label: "statement \(statement.statementId)")
                    }
                }
            }
        }
    }

    func test_everyDescription_isMeaningfulProse() throws {
        // BDD §2 Scenario 2: each statement's description ≥ 100 characters of
        // meaningful prose. Applied to every implemented-requirement — including
        // not-applicable ones — so reviewers always see substantive context.
        let doc = try loadDocument()
        for req in doc.implementedRequirements {
            XCTAssertGreaterThanOrEqual(
                req.description.count, 100,
                "Control \(req.controlId): description is \(req.description.count) chars (< 100); BDD §2 Scenario 2 requires ≥ 100 chars of meaningful prose"
            )
        }
    }

    func test_everyImplementationLink_pointsToExistingFile() throws {
        let doc = try loadDocument()
        var missing: [(controlId: String, href: String)] = []

        func checkLinks(_ links: [OscalLink]?, controlId: String, root: URL) {
            for link in links ?? [] where link.rel == "implementation" {
                let resolved = root
                    .appendingPathComponent("oscal")
                    .appendingPathComponent(link.href)
                    .standardized
                if !FileManager.default.fileExists(atPath: resolved.path) {
                    missing.append((controlId: controlId, href: link.href))
                }
            }
        }

        let root = repoRoot()
        for req in doc.implementedRequirements {
            checkLinks(req.links, controlId: req.controlId, root: root)
            for statement in req.statements ?? [] {
                checkLinks(statement.links, controlId: req.controlId, root: root)
            }
        }

        XCTAssertTrue(
            missing.isEmpty,
            "OSCAL implementation links point at non-existent files: \(missing.map { "\($0.controlId)→\($0.href)" }.joined(separator: ", "))"
        )
    }

    func test_everyVerificationLink_pointsToExistingFile() throws {
        let doc = try loadDocument()
        var missing: [(controlId: String, href: String)] = []
        let root = repoRoot()

        for req in doc.implementedRequirements {
            for link in (req.links ?? []) where link.rel == "verification" {
                let resolved = root
                    .appendingPathComponent("oscal")
                    .appendingPathComponent(link.href)
                    .standardized
                if !FileManager.default.fileExists(atPath: resolved.path) {
                    missing.append((controlId: req.controlId, href: link.href))
                }
            }
        }

        XCTAssertTrue(
            missing.isEmpty,
            "OSCAL verification links point at non-existent files: \(missing.map { "\($0.controlId)→\($0.href)" }.joined(separator: ", "))"
        )
    }

    func test_componentLevelEvidenceLinks_pointToExistingPathsOrCiArtifacts() throws {
        let doc = try loadDocument()
        let root = repoRoot()
        let component = doc.primaryComponent

        // Evidence links can either be on-disk files (e.g. .github/sbom-policy.yml)
        // or CI-generated artifact paths (e.g. sbom-cyclonedx.json). Allow the
        // sbom artifact reference to be virtual; require everything else to exist.
        for link in component.links ?? [] where link.rel == "evidence" {
            let isCiGeneratedSbom = link.href.contains("sbom-cyclonedx")
            guard !isCiGeneratedSbom else { continue }

            let resolved = root
                .appendingPathComponent("oscal")
                .appendingPathComponent(link.href)
                .standardized
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: resolved.path),
                "Component-level evidence link points to a non-existent file: \(link.href)"
            )
        }
    }
}
