// STORY: STORY-009 — Element State Polling Tool
// COMPONENT: ElementStatePollLoop (fixed-cadence poll until predicate or timeout)

import XCTest
@testable import MacOSControlLib

final class ElementStatePollLoopTests: XCTestCase {

    private func predicate(_ expr: String) throws -> ConditionPredicate {
        ConditionPredicate(try ConditionExpressionParser().parse(expr))
    }

    func test_poll_returnsSatisfied_whenPredicateBecomesTrueOnNthPoll() async throws {
        let probe = FakeElementStateProbe([
            .matched(AXNode(role: "AXButton", enabled: false)),
            .matched(AXNode(role: "AXButton", enabled: false)),
            .matched(AXNode(role: "AXButton", enabled: true)),
        ])
        let clock = FakeClock()
        let outcome = await ElementStatePollLoop().poll(
            predicate: try predicate("enabled = true"),
            probe: probe,
            timeout: 5,
            pollIntervalMs: 100,
            clock: clock
        )

        guard case .satisfied(_, _, let polls) = outcome else {
            return XCTFail("expected .satisfied, got \(outcome)")
        }
        XCTAssertEqual(polls, 3)
        XCTAssertEqual(probe.callCount, 3)
    }

    func test_poll_haltsImmediatelyOnMatch_noTrailingSleep() async throws {
        let probe = FakeElementStateProbe([
            .matched(AXNode(role: "AXButton", enabled: false)),
            .matched(AXNode(role: "AXButton", enabled: true)),
        ])
        let clock = FakeClock()
        _ = await ElementStatePollLoop().poll(
            predicate: try predicate("enabled = true"),
            probe: probe,
            timeout: 5,
            pollIntervalMs: 100,
            clock: clock
        )
        // Two probes, but only ONE inter-poll sleep (after the first miss).
        // No sleep is issued after the matching probe.
        XCTAssertEqual(clock.sleepCalls, [100])
    }

    func test_poll_returnsTimedOut_withLastStateAndCounts() async throws {
        let probe = FakeElementStateProbe([
            .matched(AXNode(role: "AXButton", title: "Submit", enabled: false)),
        ])
        let clock = FakeClock()
        let outcome = await ElementStatePollLoop().poll(
            predicate: try predicate("enabled = true"),
            probe: probe,
            timeout: 1,
            pollIntervalMs: 100,
            clock: clock
        )

        guard case .timedOut(let last, let elapsed, let polls) = outcome else {
            return XCTFail("expected .timedOut, got \(outcome)")
        }
        XCTAssertGreaterThanOrEqual(elapsed, 1)
        XCTAssertGreaterThan(polls, 1)
        guard case .matched(let node) = last else {
            return XCTFail("expected last state to carry the element")
        }
        XCTAssertEqual(node.enabled, false)
    }

    func test_poll_probesAtLeastOnceEvenWithZeroTimeout() async throws {
        let probe = FakeElementStateProbe([.matched(AXNode(role: "AXList"))])
        let outcome = await ElementStatePollLoop().poll(
            predicate: try predicate("exists = true"),
            probe: probe,
            timeout: 0,
            pollIntervalMs: 100,
            clock: FakeClock()
        )
        guard case .satisfied = outcome else {
            return XCTFail("a single probe should still satisfy exists=true")
        }
        XCTAssertEqual(probe.callCount, 1)
    }

    func test_poll_existsFalse_resolvesWhenElementDisappears() async throws {
        let probe = FakeElementStateProbe([
            .matched(AXNode(role: "AXProgressIndicator")),
            .matched(AXNode(role: "AXProgressIndicator")),
            .notFound,
        ])
        let outcome = await ElementStatePollLoop().poll(
            predicate: try predicate("exists = false"),
            probe: probe,
            timeout: 5,
            pollIntervalMs: 50,
            clock: FakeClock()
        )
        guard case .satisfied(let last, _, _) = outcome else {
            return XCTFail("expected .satisfied")
        }
        if case .matched = last { XCTFail("last result should be .notFound") }
    }
}
