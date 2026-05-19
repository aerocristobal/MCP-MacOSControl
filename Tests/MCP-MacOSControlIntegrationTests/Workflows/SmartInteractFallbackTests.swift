// STORY-012 — End-to-End Integration Validation Suite
// SCENARIO: Failure-recovery — smart_interact falls back and reports decision_log
// Re-validates: STORY-010, STORY-019
//
// Drives smart_interact against the version-controlled AX-degraded harness
// (controls marked .accessibilityHidden(true)). The semantic layer cannot
// resolve "Action", so the router must fall through and the decision_log must
// record the attempt with per-layer elapsed milliseconds.

import XCTest
import MCP
@testable import MacOSControlLib

final class SmartInteractFallbackTests: IntegrationTestCase {

    private let harness = IntegrationHarness()
    private let registry = AppCapabilityRegistry.standardRegistry()

    override func setUpWithError() throws {
        try super.setUpWithError()
        try registry.load()
    }

    func test_smartInteract_fallsBack_andReportsDecisionLog() async throws {
        let harness = self.harness
        let registry = self.registry
        let app = try AXDegradedHarnessLauncher.launch()
        defer { app.terminate() }
        try await runScenario(seconds: 20) {
            try await app.waitUntilReady()

            let clock = ContinuousClock()
            let started = clock.now

            let response = try await harness.call("smart_interact", [
                "intent": .string("click"),
                "target_description": .string("Action"),
                "application": .string(AXDegradedHarnessLauncher.processName),
                "coordinates": .object(["x": .double(app.clickPoint.x),
                                        "y": .double(app.clickPoint.y)])
            ])
            let elapsed = clock.now - started

            XCTAssertFalse(response.isError,
                "A non-semantic layer should have recovered the click: \(response.rawText)")

            // Gherkin (Scenario 5): "the response's interaction_method is
            // 'applescript' or 'coordinate_fallback'" — Scenario 2 admits
            // ax_hit_test as a third option, this scenario does not.
            let method = response.string("interaction_method")
            XCTAssertTrue(
                method == "applescript" || method == "coordinate_fallback",
                "interaction_method must be applescript or coordinate_fallback, got \(method ?? "nil")")

            let log = (response.array("decision_log") as? [[String: Any]]) ?? []
            XCTAssertFalse(log.isEmpty, "decision_log must be present")

            let ax = log.first { ($0["layer"] as? String) == "ax_semantic" }
            XCTAssertNotNil(ax, "decision_log must record the ax_semantic attempt")
            XCTAssertTrue(
                (ax?["outcome"] as? String) == "failed"
                || (ax?["outcome"] as? String) == "skipped",
                "ax_semantic outcome must be failed or skipped")

            for entry in log {
                XCTAssertNotNil(entry["elapsed_ms"] as? Int,
                                "decision_log entry missing elapsed_ms: \(entry)")
            }

            XCTAssertLessThan(elapsed, .seconds(3),
                              "Total fallback wall-clock must be under 3s")

            // §8 DoD: every scenario that observes an interaction_method
            // records it for the STORY-020 catalog feed.
            ObservationRecorder.record(
                scenario: "Failure-recovery — smart_interact falls back and reports decision_log",
                tool: "smart_interact",
                application: AXDegradedHarnessLauncher.processName,
                observed: method ?? "unknown",
                registry: registry)
        }
    }
}
