// STORY-027 — Cancellation path for ElementStatePollLoop + WaitForElementStateTool.
//
// The poll loop's contract is "cancellation halts within one poll cycle".
// Verified via FakeClock + FakeElementStateProbe so the test is fully
// deterministic (no real wall-clock dependency).

import XCTest
import MCP
@testable import MacOSControlLib

final class WaitForElementStateToolCancellationTests: XCTestCase {

    private func predicate(_ expr: String) throws -> ConditionPredicate {
        ConditionPredicate(try ConditionExpressionParser().parse(expr))
    }

    // MARK: - ElementStatePollLoop direct tests

    func test_pollLoop_returnsCancelled_whenTokenCancelledBeforeFirstProbe() async throws {
        let probe = FakeElementStateProbe([
            .matched(AXNode(role: "AXButton", enabled: false)),
        ])
        let clock = FakeClock()
        let token = CancellationToken()
        token.cancel()

        let outcome = await ElementStatePollLoop().poll(
            predicate: try predicate("enabled = true"),
            probe: probe,
            timeout: 5,
            pollIntervalMs: 100,
            clock: clock,
            cancellation: token
        )

        guard case .cancelled(let last, _, let polls) = outcome else {
            return XCTFail("expected .cancelled, got \(outcome)")
        }
        XCTAssertEqual(polls, 0)
        XCTAssertNil(last, "no probe should have run before cancellation")
        XCTAssertEqual(probe.callCount, 0, "no AX reads after cancellation")
    }

    func test_pollLoop_returnsCancelled_whenTokenCancelledBetweenProbes() async throws {
        // Two probes scheduled; cancel after the first so the second never runs.
        let probe = FakeElementStateProbe([
            .matched(AXNode(role: "AXButton", enabled: false)),
            .matched(AXNode(role: "AXButton", enabled: false)),
            .matched(AXNode(role: "AXButton", enabled: true)),
        ])
        let clock = FakeClock()
        let token = CancellationToken()

        // Cancel mid-flight: probe runs once, then we cancel before next cycle.
        probe.afterEachProbe = { [token, probe] in
            if probe.callCount == 1 {
                token.cancel()
            }
        }

        let outcome = await ElementStatePollLoop().poll(
            predicate: try predicate("enabled = true"),
            probe: probe,
            timeout: 5,
            pollIntervalMs: 100,
            clock: clock,
            cancellation: token
        )

        guard case .cancelled(_, _, let polls) = outcome else {
            return XCTFail("expected .cancelled, got \(outcome)")
        }
        XCTAssertEqual(polls, 1, "polls counter records the one probe that completed before cancel")
        XCTAssertEqual(probe.callCount, 1, "no further AX reads after cancellation")
    }

    // MARK: - Tool-level: structured cancelled envelope

    func test_tool_returnsCancelledStructuredError_whenContextCancelledMidPoll() async throws {
        let probe = FakeElementStateProbe([
            .matched(AXNode(role: "AXButton", enabled: false)),
            .matched(AXNode(role: "AXButton", enabled: false)),
        ])
        let clock = FakeClock()
        let token = CancellationToken()

        probe.afterEachProbe = { [token, probe] in
            if probe.callCount == 1 {
                token.cancel()
            }
        }

        let tool = WaitForElementStateTool(
            probeFactory: { _, _, _ in probe },
            clock: clock,
            pidResolver: { _ in (42, "com.example.TextEdit") },
            permissionCheck: { true },
            pollIntervalMs: 100
        )

        let context = ToolCallContext(requestId: "req-poll", cancellation: token)
        let params = makeParams(name: "wait_for_element_state", args: [
            "condition": .string("enabled = true"),
            "application": .string("TextEdit")
        ])
        let result = await tool.execute(params, context: context)

        XCTAssertEqual(result.isError, true)
        let text = extractText(from: result) ?? ""
        XCTAssertTrue(text.contains("\"code\":\"cancelled\""),
                      "expected cancelled envelope, got: \(text)")
    }
}
