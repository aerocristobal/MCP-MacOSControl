// STORY-027 — Cancellation path through WaitForAppEventTool.
//
// Exercises the tool layer with FakeNSWorkspaceEventManaging. Verifies that
// the tool forwards the token, cancels mid-wait map to the structured
// cancelled envelope, and pre-cancelled context short-circuits before any
// observer is installed.

import XCTest
import MCP
@testable import MacOSControlLib

final class WaitForAppEventToolCancellationTests: XCTestCase {

    private var manager: FakeNSWorkspaceEventManaging!
    private var tool: WaitForAppEventTool!

    override func setUp() {
        super.setUp()
        manager = FakeNSWorkspaceEventManaging()
        tool = WaitForAppEventTool(manager: manager)
    }

    func test_execute_passesCancellationTokenToManager() async {
        let token = CancellationToken()
        let context = ToolCallContext(requestId: "req-a", cancellation: token)
        let params = makeParams(name: "wait_for_app_event", args: [
            "event": .string("launched"),
            "timeout_seconds": .double(1)
        ])
        _ = await tool.execute(params, context: context)
        XCTAssertTrue(manager.lastCancellation === token)
        XCTAssertEqual(manager.cancellationObserverCount, 1)
    }

    func test_execute_returnsCancelledEnvelope_whenTokenCancelledMidWait() async {
        manager.simulatedDelayNanoseconds = 200_000_000
        let token = CancellationToken()
        let context = ToolCallContext(requestId: "req-b", cancellation: token)
        let params = makeParams(name: "wait_for_app_event", args: [
            "event": .string("launched"),
            "timeout_seconds": .double(5)
        ])
        let task = Task { await tool.execute(params, context: context) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        token.cancel()
        let result = await task.value

        XCTAssertEqual(result.isError, true)
        let text = extractText(from: result) ?? ""
        XCTAssertTrue(text.contains("\"code\":\"cancelled\""),
                      "expected cancelled envelope, got: \(text)")
    }

    func test_execute_preCancelledContext_returnsCancelledImmediately() async {
        let token = CancellationToken()
        token.cancel()
        let context = ToolCallContext(requestId: "req-c", cancellation: token)
        manager.simulatedDelayNanoseconds = 5_000_000_000
        let params = makeParams(name: "wait_for_app_event", args: [
            "event": .string("launched"),
            "timeout_seconds": .double(30)
        ])

        let start = Date()
        let result = await tool.execute(params, context: context)
        let elapsedMs = Date().timeIntervalSince(start) * 1000

        XCTAssertEqual(result.isError, true)
        XCTAssertLessThan(elapsedMs, 200)
        let text = extractText(from: result) ?? ""
        XCTAssertTrue(text.contains("\"code\":\"cancelled\""))
    }
}
