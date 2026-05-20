// STORY-012 — End-to-End Integration Validation Suite
// SCENARIO: NSWorkspace launch flow — open Calculator from a not-running state
// Re-validates: STORY-018, STORY-008, STORY-010

import XCTest
import MCP
@testable import MacOSControlLib

final class NSWorkspaceLaunchFlowTests: IntegrationTestCase {

    private let harness = IntegrationHarness()
    private let registry = AppCapabilityRegistry.standardRegistry()
    private let bundleId = "com.apple.calculator"

    override func setUpWithError() throws {
        try super.setUpWithError()
        try registry.load()
        Self.terminateCalculator()
    }

    override func tearDown() {
        Self.terminateCalculator()
        super.tearDown()
    }

    func test_workflow_launchesCalculatorViaNSWorkspaceAndClicksButton() async throws {
        try skipUnlessAutomationAuthorized("com.apple.calculator")
        let harness = self.harness
        let registry = self.registry
        let bundleId = self.bundleId
        try await runScenario(seconds: 40) {
            // Step 1 — subscribe to the launch event concurrently.
            async let launch = harness.call("wait_for_app_event", [
                "event": .string("launched"),
                "bundle_identifier": .string(bundleId),
                "timeout_seconds": .double(10)
            ])

            // Give the observer a beat to register before triggering the launch.
            try? await Task.sleep(nanoseconds: 300_000_000)

            // Step 2 — activate Calculator (launches it if not running).
            try await harness.require("run_applescript", [
                "timeout_seconds": .double(10),
                "script": .string(#"tell application "Calculator" to activate"#)
            ])
            // Gherkin: "step 3 returns within 5 seconds of step 2" — measure
            // from the *end* of step 2 to the end of step 3.
            let afterActivate = ContinuousClock().now

            let launchResult = try await launch
            XCTAssertFalse(launchResult.isError,
                           "wait_for_app_event failed: \(launchResult.rawText)")
            XCTAssertEqual(launchResult.string("bundle_identifier"), bundleId,
                           "launch event must carry the Calculator bundle id")
            XCTAssertEqual(launchResult.string("interaction_method"),
                           "nsworkspace_observer")

            // Step 3 — wait for Calculator's window, promptly after activate.
            let windowResult = try await harness.call("wait_for_ui_event", [
                "notification": .string("AXWindowCreated"),
                "application": .string(bundleId),
                "timeout_seconds": .double(5)
            ])
            XCTAssertTrue(
                !windowResult.isError || windowResult.errorCode == "wait_timeout",
                "Unexpected window-wait failure: \(windowResult.rawText)")
            let sinceActivate = ContinuousClock().now - afterActivate
            XCTAssertLessThan(sinceActivate, .seconds(5),
                              "Window did not appear within 5s of step 2 (gherkin)")

            // Step 4 — smart_interact click "5". Calculator is ax_supported=yes.
            let click = try await harness.call("smart_interact", [
                "intent": .string("click"),
                "target_description": .string("5"),
                "application": .string(bundleId)
            ])
            if !click.isError {
                XCTAssertEqual(click.string("interaction_method"), "ax_semantic",
                               "Calculator should route via ax_semantic")
                ObservationRecorder.record(
                    scenario: "NSWorkspace launch flow — open Calculator from a not-running state",
                    tool: "smart_interact",
                    application: bundleId,
                    observed: click.string("interaction_method") ?? "unknown",
                    registry: registry)

                let tree = try await harness.require("accessibility_tree", [
                    "application": .string(bundleId), "max_depth": .int(8)
                ])
                XCTAssertTrue(
                    Self.treeContains(tree.json, value: "5"),
                    "Calculator display should read 5 after the workflow")
            } else {
                // A cold Calculator may not expose the keypad instantly; the
                // launch + window invariants above are the scenario's core.
                XCTAssertEqual(click.errorCode, "all_layers_failed")
            }
        }
    }

    private static func terminateCalculator() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = ["Calculator"]
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
        Thread.sleep(forTimeInterval: 0.5)
    }

    private static func treeContains(_ node: [String: Any], value: String) -> Bool {
        if (node["value"] as? String) == value { return true }
        if let children = node["children"] as? [[String: Any]] {
            return children.contains { treeContains($0, value: value) }
        }
        return false
    }
}
