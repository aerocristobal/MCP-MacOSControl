// FILE: Tests/MCP-MacOSControlTests/Compliance/EventTypeMappingTests.swift
// STORY: STORY-037 — OSCAL Assessment Results & POA&M Artifacts
// COMPONENT: EventTypeMapping
//
// Verifies the BDD Scenario Outline at §2 of the story:
//   | event_type                       | method      | controls          |
//
// Plus the structural promise: every AuditEventType has a mapping row,
// and every row's `controls` references control IDs that exist in
// oscal/component-definition.json.

import XCTest
import MacOSControlLib
@testable import OSCALComplianceSupport

final class EventTypeMappingTests: XCTestCase {

    private let mapping = EventTypeMapping.default

    private func repoRoot() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    // MARK: - Coverage

    func test_mapper_eachEventTypeHasMethod() throws {
        for eventType in AuditEventType.allCases {
            // Sample one disposition per event type so we exercise the
            // first-line case in every arm of the switch. The mapper is
            // disposition-aware for applescript_execute and treats other
            // event types as disposition-independent.
            let disposition: AuditFilterDisposition
            switch eventType {
            case .applescriptExecute: disposition = .allowed
            default: disposition = .notApplicable
            }
            let record = AuditRecord.fixture(eventType: eventType, filterDisposition: disposition)
            let entry = mapping.entry(for: record)
            XCTAssertNotNil(entry, "EventTypeMapping has no entry for \(eventType.rawValue)")
            XCTAssertFalse(entry?.methods.isEmpty ?? true, "Mapping for \(eventType.rawValue) has empty methods")
            XCTAssertFalse(entry?.controls.isEmpty ?? true, "Mapping for \(eventType.rawValue) has empty controls")
        }
    }

    func test_mapper_appleScriptExecutedMapsToExamineWithAU2AU3CM7() throws {
        let record = AuditRecord.fixture(eventType: .applescriptExecute, filterDisposition: .allowed)
        guard let entry = mapping.entry(for: record) else { return XCTFail() }
        XCTAssertEqual(entry.observationTitle, "applescript_executed")
        XCTAssertEqual(entry.methods, ["EXAMINE"])
        XCTAssertEqual(Set(entry.controls), Set(["au-2", "au-3", "cm-7"]))
        XCTAssertFalse(entry.elevated)
    }

    func test_mapper_appleScriptRejectedMapsToSI10CM7_underSecurityDisposition() throws {
        let record = AuditRecord.fixture(eventType: .applescriptExecute, filterDisposition: .rejectedSecurity)
        guard let entry = mapping.entry(for: record) else { return XCTFail() }
        XCTAssertEqual(entry.observationTitle, "applescript_rejected")
        XCTAssertEqual(Set(entry.controls), Set(["si-10", "cm-7"]))
    }

    func test_mapper_appleScriptRejectedMapsToSI10CM7_underPermissionDisposition() throws {
        let record = AuditRecord.fixture(eventType: .applescriptExecute, filterDisposition: .rejectedPermission)
        guard let entry = mapping.entry(for: record) else { return XCTFail() }
        XCTAssertEqual(entry.observationTitle, "applescript_rejected")
        XCTAssertEqual(Set(entry.controls), Set(["si-10", "cm-7"]))
    }

    func test_mapper_menuClickMapsToAU2AU3() throws {
        let record = AuditRecord.fixture(eventType: .menuClick, filterDisposition: .allowed)
        guard let entry = mapping.entry(for: record) else { return XCTFail() }
        XCTAssertEqual(entry.observationTitle, "click_menu_item_invoked")
        XCTAssertEqual(Set(entry.controls), Set(["au-2", "au-3"]))
    }

    func test_mapper_chainBreakMapsToTestWithAU9_andIsElevated() throws {
        let record = AuditRecord.fixture(eventType: .chainVerificationFailure)
        guard let entry = mapping.entry(for: record) else { return XCTFail() }
        XCTAssertEqual(entry.observationTitle, "run_applescript_audit_chain_break")
        XCTAssertEqual(entry.methods, ["TEST"])
        XCTAssertEqual(Set(entry.controls), Set(["au-9"]))
        XCTAssertTrue(entry.elevated, "Chain-break observations must be elevated severity")
    }

    func test_mapper_administrativeRotateMapsToAU9AU11() throws {
        let record = AuditRecord.fixture(eventType: .administrativeForceRotateUnacked)
        guard let entry = mapping.entry(for: record) else { return XCTFail() }
        XCTAssertEqual(Set(entry.controls), Set(["au-9", "au-11"]))
    }

    // MARK: - Cross-artifact consistency

    /// Every control id referenced by EventTypeMapping must exist in
    /// oscal/component-definition.json. Catches drift between the
    /// mapping and the controls actually implemented.
    func test_mapper_controlReferencesExistInOscalComponentDefinition() throws {
        let checker = OscalCoverageChecker(
            componentDefinitionPath: repoRoot().appendingPathComponent("oscal/component-definition.json").path,
            securityMdPath: repoRoot().appendingPathComponent("docs/SECURITY.md").path
        )
        let report = try checker.report()
        var missing: Set<String> = []
        for eventType in AuditEventType.allCases {
            let disposition: AuditFilterDisposition = eventType == .applescriptExecute ? .allowed : .notApplicable
            let record = AuditRecord.fixture(eventType: eventType, filterDisposition: disposition)
            guard let entry = mapping.entry(for: record) else { continue }
            for c in entry.controls where !report.implementedControls.contains(c) {
                missing.insert(c)
            }
        }
        XCTAssertTrue(missing.isEmpty, "EventTypeMapping references controls not in component-definition.json: \(missing.sorted())")
    }
}
