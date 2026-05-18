// STORY: STORY-008 — AXObserver Wait for UI Event Tool
// COMPONENT: AXObserverManager (multiplexed subscription manager)

import XCTest
@testable import MacOSControlLib

final class AXObserverManagerTests: XCTestCase {

    var manager: AXObserverManager!
    var fakeAXBridge: FakeAXObserverBridge!
    var fakeWorkspace: FakeWorkspaceTerminationObserver!

    override func setUp() {
        super.setUp()
        fakeAXBridge = FakeAXObserverBridge()
        fakeWorkspace = FakeWorkspaceTerminationObserver()
        manager = AXObserverManager(axBridge: fakeAXBridge, workspace: fakeWorkspace)
    }

    /// Allow the actor's `attach` task to run before driving the fake bridge.
    /// The wait() entrypoint hops onto the actor via an unstructured Task —
    /// firing the notification synchronously after `async let` returns is a
    /// race. 50 ms is the same budget the scaffold uses.
    private func waitForActorAttach(_ ms: UInt64 = 50) async {
        try? await Task.sleep(nanoseconds: ms * 1_000_000)
    }

    // MARK: - Happy path

    func test_wait_returnsSuccess_whenNotificationFires() async throws {
        let pid: pid_t = 1234
        async let result = manager.wait(for: "AXWindowCreated", in: pid, timeout: 5)
        await waitForActorAttach()
        fakeAXBridge.fireNotification("AXWindowCreated", for: pid)
        let event = try await result
        XCTAssertEqual(event.notification, "AXWindowCreated")
    }

    // MARK: - Subscription multiplexing

    func test_wait_multiplexesTwoCallers_ontoOneUnderlyingObserver() async throws {
        let pid: pid_t = 1234
        async let r1 = manager.wait(for: "AXWindowCreated", in: pid, timeout: 5)
        async let r2 = manager.wait(for: "AXWindowCreated", in: pid, timeout: 5)
        await waitForActorAttach()
        XCTAssertEqual(fakeAXBridge.observerCreateCallCount, 1,
                       "two concurrent waiters on the same key must share one underlying AXObserver")
        fakeAXBridge.fireNotification("AXWindowCreated", for: pid)
        let (e1, e2) = try await (r1, r2)
        XCTAssertEqual(e1.notification, "AXWindowCreated")
        XCTAssertEqual(e2.notification, "AXWindowCreated")
    }

    func test_wait_unregistersObserver_afterLastWaiterResolves() async throws {
        let pid: pid_t = 1234
        async let r1 = manager.wait(for: "AXWindowCreated", in: pid, timeout: 5)
        await waitForActorAttach()
        fakeAXBridge.fireNotification("AXWindowCreated", for: pid)
        _ = try await r1
        XCTAssertEqual(fakeAXBridge.observerRemoveCallCount, 1)
        XCTAssertEqual(fakeAXBridge.activeSubscriptionCount, 0)
    }

    // MARK: - Error paths

    func test_wait_throwsWaitTimeoutError_whenDeadlineElapses() async {
        let pid: pid_t = 1234
        do {
            _ = try await manager.wait(for: "AXWindowCreated", in: pid, timeout: 0.1)
            XCTFail("Expected WaitTimeoutError")
        } catch let error as WaitTimeoutError {
            XCTAssertEqual(error.notification, "AXWindowCreated")
            XCTAssertGreaterThanOrEqual(error.elapsedSeconds, 0.1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_wait_throwsTargetTerminatedError_whenAppQuitsMidWait() async {
        let pid: pid_t = 1234
        async let result = manager.wait(for: "AXWindowCreated", in: pid, timeout: 5)
        await waitForActorAttach()
        fakeWorkspace.fireTerminated(pid: pid, bundleId: "com.apple.TextEdit")
        do {
            _ = try await result
            XCTFail("Expected TargetApplicationTerminatedError")
        } catch let error as TargetApplicationTerminatedError {
            XCTAssertEqual(error.bundleIdentifier, "com.apple.TextEdit")
            XCTAssertEqual(error.pid, pid)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_wait_throwsPermissionError_whenAXNotTrusted() async {
        fakeAXBridge.isProcessTrusted = false
        do {
            _ = try await manager.wait(for: "AXWindowCreated", in: 1234, timeout: 5)
            XCTFail("Expected AccessibilityPermissionRequiredError")
        } catch is AccessibilityPermissionRequiredError {
            XCTAssertEqual(fakeAXBridge.observerCreateCallCount, 0,
                           "permission gate must short-circuit BEFORE any AX observer is created")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Leak prevention

    func test_wait_doesNotLeakRunLoopSource_onTimeout() async {
        let pid: pid_t = 1234
        _ = try? await manager.wait(for: "AXWindowCreated", in: pid, timeout: 0.05)
        XCTAssertEqual(fakeAXBridge.observerRemoveCallCount, 1,
                       "timeout must trigger observer cancel exactly once")
        XCTAssertEqual(fakeAXBridge.runLoopSourceRemovalCount, 1,
                       "timeout must remove the CFRunLoopSource paired with the cancelled observer")
        XCTAssertEqual(fakeAXBridge.activeSubscriptionCount, 0)
    }

    func test_wait_doesNotLeakObserver_onTermination() async {
        let pid: pid_t = 1234
        async let r1 = manager.wait(for: "AXWindowCreated", in: pid, timeout: 5)
        async let r2 = manager.wait(for: "AXValueChanged", in: pid, timeout: 5)
        await waitForActorAttach()
        fakeWorkspace.fireTerminated(pid: pid, bundleId: "com.apple.TextEdit")
        _ = try? await r1
        _ = try? await r2
        XCTAssertEqual(fakeAXBridge.activeSubscriptionCount, 0,
                       "termination must tear down EVERY subscription on the terminated pid")
    }

    /// Stress test from DoD: 100 sequential timeouts produce 100 observer
    /// removals and zero leaked subscriptions.
    func test_wait_stressTest_noLeakedSubscriptionsAfter100SequentialTimeouts() async {
        for _ in 0..<100 {
            _ = try? await manager.wait(for: "AXWindowCreated", in: 1234, timeout: 0.02)
        }
        XCTAssertEqual(fakeAXBridge.activeSubscriptionCount, 0)
        XCTAssertEqual(fakeAXBridge.observerRemoveCallCount, 100)
    }

    // MARK: - Notification set

    func test_wait_dispatchesEachSupportedNotificationConstant() async throws {
        let pid: pid_t = 1234
        for notification in AXObserverNotification.supported {
            async let result = manager.wait(for: notification, in: pid, timeout: 5)
            await waitForActorAttach()
            fakeAXBridge.fireNotification(notification, for: pid)
            let event = try await result
            XCTAssertEqual(event.notification, notification)
        }
    }

    // MARK: - canSubscribe gate

    func test_canSubscribe_proxiesIsProcessTrusted() async {
        fakeAXBridge.isProcessTrusted = false
        let denied = await manager.canSubscribe()
        XCTAssertFalse(denied)

        fakeAXBridge.isProcessTrusted = true
        let granted = await manager.canSubscribe()
        XCTAssertTrue(granted)
    }
}
