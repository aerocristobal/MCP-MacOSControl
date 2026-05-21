// STORY-027 — Cancellation behaviour of the AXObserverManager actor.
//
// These tests are at the manager level (not the tool level) so the
// init-race scenario from the BDD outline — "cancellation while the
// AXObserver subscription is initializing is idempotent" — can be
// exercised deterministically against the actor's serialised state.

import XCTest
@testable import MacOSControlLib

final class AXObserverManagerCancellationTests: XCTestCase {

    private var manager: AXObserverManager!
    private var fakeAXBridge: FakeAXObserverBridge!
    private var fakeWorkspace: FakeWorkspaceTerminationObserver!

    override func setUp() {
        super.setUp()
        fakeAXBridge = FakeAXObserverBridge()
        fakeWorkspace = FakeWorkspaceTerminationObserver()
        manager = AXObserverManager(axBridge: fakeAXBridge, workspace: fakeWorkspace)
    }

    private func waitForActorAttach(_ ms: UInt64 = 50) async {
        try? await Task.sleep(nanoseconds: ms * 1_000_000)
    }

    func test_wait_throwsCancellationError_whenTokenCancelledAfterAttach() async {
        let pid: pid_t = 1234
        let token = CancellationToken()
        async let result = manager.wait(
            for: "AXWindowCreated",
            in: pid,
            timeout: 5,
            cancellation: token
        )
        await waitForActorAttach()
        // At this point the subscription is installed.
        XCTAssertEqual(fakeAXBridge.observerCreateCallCount, 1)
        token.cancel()
        do {
            _ = try await result
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        // Wait one tick for the cancel Task to land on the actor.
        await waitForActorAttach(20)
        XCTAssertEqual(fakeAXBridge.observerRemoveCallCount, 1,
                       "the last waiter leaving must tear down the underlying observer")
        XCTAssertEqual(fakeAXBridge.activeSubscriptionCount, 0)
    }

    func test_wait_preCancelledToken_neverInstallsSubscription() async {
        let pid: pid_t = 1234
        let token = CancellationToken()
        token.cancel()

        do {
            _ = try await manager.wait(
                for: "AXWindowCreated",
                in: pid,
                timeout: 5,
                cancellation: token
            )
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // expected — fast-path at wait() entry
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(fakeAXBridge.observerCreateCallCount, 0,
                       "pre-cancelled token must short-circuit before subscription install")
        XCTAssertEqual(fakeAXBridge.activeSubscriptionCount, 0)
    }

    func test_wait_cancelDuringInitRace_neverLeavesActiveObserver() async {
        // Reproduces the BDD init-race scenario: cancel fires AFTER wait()
        // has returned its continuation but BEFORE the attach Task has had
        // a chance to run on the actor. Both paths (cancel-task first or
        // attach-task first) must leave zero active observers.
        let pid: pid_t = 1234
        let token = CancellationToken()

        async let result = manager.wait(
            for: "AXWindowCreated",
            in: pid,
            timeout: 5,
            cancellation: token
        )
        // Cancel IMMEDIATELY without waitForActorAttach — cancel-task and
        // attach-task race for the actor.
        token.cancel()

        do {
            _ = try await result
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await waitForActorAttach(20)
        XCTAssertEqual(fakeAXBridge.activeSubscriptionCount, 0,
                       "no AXObserver may remain after the init-race resolves")
    }

    func test_wait_sharedSubscription_otherWaiterSurvivesCancellation() async throws {
        // Two concurrent waiters on the same key share one underlying
        // AXObserver. Cancelling one waiter must NOT tear down the observer
        // while the other waiter is still subscribed.
        let pid: pid_t = 1234
        let token1 = CancellationToken()

        async let r1 = manager.wait(
            for: "AXWindowCreated",
            in: pid,
            timeout: 5,
            cancellation: token1
        )
        async let r2 = manager.wait(
            for: "AXWindowCreated",
            in: pid,
            timeout: 5
        )
        await waitForActorAttach()

        XCTAssertEqual(fakeAXBridge.observerCreateCallCount, 1,
                       "two waiters on the same key share one underlying observer")

        token1.cancel()
        do {
            _ = try await r1
            XCTFail("Expected first waiter to be cancelled")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Underlying observer must still be active for the second waiter.
        XCTAssertEqual(fakeAXBridge.activeSubscriptionCount, 1,
                       "shared observer must survive while another waiter remains")

        fakeAXBridge.fireNotification("AXWindowCreated", for: pid)
        let event = try await r2
        XCTAssertEqual(event.notification, "AXWindowCreated")

        await waitForActorAttach(20)
        XCTAssertEqual(fakeAXBridge.activeSubscriptionCount, 0,
                       "last waiter leaving tears down the shared observer")
    }
}
