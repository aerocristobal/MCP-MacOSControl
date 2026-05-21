// STORY-027 — Cancellation path through WaitForUIEventTool.
//
// Exercises the tool layer with FakeAXObserverManager. The fake wires the
// cancellation token through to a polling loop so cancelling the token
// mid-sleep produces a CancellationError that the tool maps to the
// structured `cancelled` error response (or surfaces upstream so the SDK
// can suppress the response).

import XCTest
import MCP
@testable import MacOSControlLib

final class WaitForUIEventToolCancellationTests: XCTestCase {

    private var fakeManager: FakeAXObserverManager!
    private var resolverSpy: AXElementResolverSpy!
    private var tool: WaitForUIEventTool!

    override func setUp() {
        super.setUp()
        fakeManager = FakeAXObserverManager()
        resolverSpy = AXElementResolverSpy()
        // Static PID resolver so we don't need real apps.
        tool = WaitForUIEventTool(
            manager: fakeManager,
            resolver: resolverSpy,
            pidResolver: { _ in (42, "com.example.TextEdit") }
        )
    }

    func test_execute_passesCancellationTokenToManager() async {
        let token = CancellationToken()
        let context = ToolCallContext(requestId: "req-1", cancellation: token)

        let params = makeParams(name: "wait_for_ui_event", args: [
            "notification": .string("AXWindowCreated"),
            "application": .string("TextEdit"),
            "timeout_seconds": .double(1)
        ])

        _ = await tool.execute(params, context: context)
        XCTAssertTrue(fakeManager.lastCancellation === token,
                      "tool must forward the caller's CancellationToken to the manager")
        XCTAssertEqual(fakeManager.cancellationObserverCount, 1)
    }

    func test_execute_returnsCancelledStructuredError_whenTokenCancelledMidWait() async {
        fakeManager.simulatedDelayNanoseconds = 200_000_000 // 200ms
        let token = CancellationToken()
        let context = ToolCallContext(requestId: "req-2", cancellation: token)

        let params = makeParams(name: "wait_for_ui_event", args: [
            "notification": .string("AXWindowCreated"),
            "application": .string("TextEdit"),
            "timeout_seconds": .double(5)
        ])

        let task = Task {
            await tool.execute(params, context: context)
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        token.cancel()
        let result = await task.value

        XCTAssertEqual(result.isError, true)
        let text = extractText(from: result) ?? ""
        XCTAssertTrue(text.contains("\"code\":\"cancelled\""),
                      "expected structured cancelled error envelope, got: \(text)")
    }

    func test_execute_preCancelledContext_returnsCancelledImmediately() async {
        let token = CancellationToken()
        token.cancel()
        let context = ToolCallContext(requestId: "req-3", cancellation: token)
        fakeManager.simulatedDelayNanoseconds = 5_000_000_000 // 5s (never reached)

        let params = makeParams(name: "wait_for_ui_event", args: [
            "notification": .string("AXWindowCreated"),
            "application": .string("TextEdit"),
            "timeout_seconds": .double(30)
        ])

        let start = Date()
        let result = await tool.execute(params, context: context)
        let elapsedMs = Date().timeIntervalSince(start) * 1000

        XCTAssertEqual(result.isError, true)
        XCTAssertLessThan(elapsedMs, 200,
                          "pre-cancelled token must short-circuit before honouring simulated delay")
        let text = extractText(from: result) ?? ""
        XCTAssertTrue(text.contains("\"code\":\"cancelled\""))
    }
}
