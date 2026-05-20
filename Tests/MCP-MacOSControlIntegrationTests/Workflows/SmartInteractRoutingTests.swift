// STORY-012 — End-to-End Integration Validation Suite
// SCENARIO: Validate interaction method selection across app types
// Re-validates: STORY-010, STORY-019

import XCTest
import MCP
@testable import MacOSControlLib

final class SmartInteractRoutingTests: IntegrationTestCase {

    private let harness = IntegrationHarness()
    private let registry = AppCapabilityRegistry.standardRegistry()

    override func setUpWithError() throws {
        try super.setUpWithError()
        try registry.load()
    }

    func test_smartInteract_pickAxSemantic_forAxSupportedApp() async throws {
        try skipUnlessAutomationAuthorized("com.apple.TextEdit")
        let harness = self.harness
        let registry = self.registry
        try await runScenario(seconds: 35) {
            // TextEdit is ax_supported=yes in the shipped registry → ax_semantic.
            try await harness.require("run_applescript", [
                "timeout_seconds": .double(10),
                "script": .string(#"tell application "TextEdit" to activate"#)
            ])
            _ = try await harness.call("wait_for_ui_event", [
                "notification": .string("AXWindowCreated"),
                "application": .string("com.apple.TextEdit"),
                "timeout_seconds": .double(4)
            ])

            let response = try await harness.call("smart_interact", [
                "intent": .string("click"),
                "target_description": .string("Bold"),
                "application": .string("com.apple.TextEdit")
            ])

            // The router always emits a decision_log; on success it carries
            // interaction_method. A clean TextEdit doc may lack a "Bold"
            // control, so accept either a successful ax_semantic resolution or
            // all_layers_failed whose log proves ax_semantic was attempted
            // first.
            if !response.isError {
                let method = response.string("interaction_method")
                XCTAssertEqual(method, "ax_semantic",
                    "TextEdit should route via ax_semantic, got \(method ?? "nil")")
                XCTAssertFalse((response.array("decision_log") ?? []).isEmpty,
                               "decision_log must be non-empty")
                ObservationRecorder.record(
                    scenario: "Validate interaction method selection across app types",
                    tool: "smart_interact",
                    application: "com.apple.TextEdit",
                    observed: method ?? "unknown",
                    registry: registry)
            } else {
                XCTAssertEqual(response.errorCode, "all_layers_failed")
                let log = response.details?["decision_log"] as? [[String: Any]] ?? []
                XCTAssertEqual(log.first?["layer"] as? String, "ax_semantic",
                               "ax_semantic must be the first attempted layer")
            }
        }
    }

    func test_smartInteract_fallsBack_forAxDegradedApp() async throws {
        let harness = self.harness
        let registry = self.registry
        let app = try AXDegradedHarnessLauncher.launch()
        defer { app.terminate() }
        try await runScenario(seconds: 25) {
            try await app.waitUntilReady()

            // Coordinates let the coordinate layer succeed once the semantic
            // layer fails against the (intentionally) empty AX tree.
            let response = try await harness.call("smart_interact", [
                "intent": .string("click"),
                "target_description": .string("Action"),
                "application": .string(AXDegradedHarnessLauncher.processName),
                "coordinates": .object(["x": .double(app.clickPoint.x),
                                        "y": .double(app.clickPoint.y)])
            ])

            XCTAssertFalse(response.isError,
                "Expected a fallback layer to succeed: \(response.rawText)")
            let method = response.string("interaction_method")
            XCTAssertTrue(
                method == "applescript"
                || method == "ax_hit_test"
                || method == "coordinate_fallback",
                "AX-degraded app must NOT resolve via ax_semantic; got \(method ?? "nil")")

            let log = (response.array("decision_log") as? [[String: Any]]) ?? []
            let ax = log.first { ($0["layer"] as? String) == "ax_semantic" }
            XCTAssertNotNil(ax, "decision_log must record the ax_semantic attempt")
            XCTAssertTrue(
                (ax?["outcome"] as? String) == "failed"
                || (ax?["outcome"] as? String) == "skipped",
                "ax_semantic must be failed/skipped for the degraded app")

            // STORY-020 feed: the harness app is registry-unknown, so this
            // records the observed fallback method with no expectation (no
            // false regression) and guarantees the artifact is produced.
            ObservationRecorder.record(
                scenario: "Validate interaction method selection across app types",
                tool: "smart_interact",
                application: AXDegradedHarnessLauncher.processName,
                observed: method ?? "unknown",
                registry: registry)
        }
    }
}
