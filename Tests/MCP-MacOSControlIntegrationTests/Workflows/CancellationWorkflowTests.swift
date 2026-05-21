// STORY-027 — End-to-End cancellation flow.
//
// Dispatches a real long-running tool via ToolRouter, then cancels the
// CancellationToken in the call context and confirms the tool tears down
// within budget. The 1000-cycle stress / leak verification is scoped to
// STORY-031; these scenarios only verify the happy-path cancellation flow
// for the two highest-value tools (run_applescript and wait_for_ui_event).

import XCTest
import MCP
@testable import MacOSControlLib

final class CancellationWorkflowTests: IntegrationTestCase {

    func test_workflow_cancellingRunAppleScript_terminatesOsascriptWithinBudget() async throws {
        try skipUnlessAutomationAuthorized("com.apple.finder")

        let token = MacOSControlLib.CancellationToken()
        let context = MacOSControlLib.ToolCallContext(
            requestId: "cancel-workflow-1",
            cancellation: token
        )

        try await runScenario(seconds: 10) {
            let dispatchTask = Task {
                try await ToolRouter.handle(
                    CallTool.Parameters(name: "run_applescript", arguments: [
                        "script": .string("delay 60"),
                        "timeout_seconds": .int(120)
                    ]),
                    context: context
                )
            }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s of real work
            let cancelStart = ContinuousClock().now
            token.cancel()
            let result = try await dispatchTask.value
            let elapsedMs = (ContinuousClock().now - cancelStart).inMilliseconds

            // Either the structured cancelled envelope arrived in the race
            // window, or the tool aborted via CancellationError which the
            // router maps to the same envelope. Either way: isError=true.
            XCTAssertTrue(result.isError ?? false)
            XCTAssertLessThan(elapsedMs, 1800,
                              "cancellation should reap subprocess within SIGTERM+SIGKILL budget")
        }
    }

    func test_workflow_cancellingWaitForUIEvent_releasesObserverPromptly() async throws {
        let token = MacOSControlLib.CancellationToken()
        let context = MacOSControlLib.ToolCallContext(
            requestId: "cancel-workflow-2",
            cancellation: token
        )

        try await runScenario(seconds: 10) {
            let dispatchTask = Task {
                try await ToolRouter.handle(
                    CallTool.Parameters(name: "wait_for_ui_event", arguments: [
                        "notification": .string("AXWindowCreated"),
                        "application": .string("Finder"),
                        "timeout_seconds": .double(30)
                    ]),
                    context: context
                )
            }
            try await Task.sleep(nanoseconds: 300_000_000)
            let cancelStart = ContinuousClock().now
            token.cancel()
            let result = try await dispatchTask.value
            let elapsedMs = (ContinuousClock().now - cancelStart).inMilliseconds

            XCTAssertTrue(result.isError ?? false)
            XCTAssertLessThan(elapsedMs, 500,
                              "wait_for_ui_event cancellation should release observer within budget")
        }
    }
}

private extension Duration {
    var inMilliseconds: Double {
        let (sec, attoseconds) = components
        return Double(sec) * 1000 + Double(attoseconds) / 1e15
    }
}
