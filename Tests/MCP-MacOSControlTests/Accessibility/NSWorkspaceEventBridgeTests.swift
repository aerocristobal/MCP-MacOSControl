// STORY: STORY-018 — Wait for Application Lifecycle Event Tool
// COMPONENT: NSWorkspaceEventBridge

import XCTest
@testable import MacOSControlLib

final class NSWorkspaceEventBridgeTests: XCTestCase {

    var bridge: NSWorkspaceEventBridge!
    var fake: FakeNotificationCenter!

    override func setUp() {
        super.setUp()
        fake = FakeNotificationCenter()
        bridge = NSWorkspaceEventBridge(notificationCenter: fake)
    }

    /// Lets the actor's `attach` task register the observer before we fire.
    private func settle() async {
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    // MARK: - Happy path

    func test_wait_resolvesWhenLaunchNotificationFires() async throws {
        async let result = bridge.wait(
            event: .launched, bundleIdentifierFilter: "com.apple.calculator", timeout: 5)
        await settle()
        fake.fireLaunched(bundleId: "com.apple.calculator", pid: 4321, name: "Calculator")
        let event = try await result
        XCTAssertEqual(event.bundleIdentifier, "com.apple.calculator")
        XCTAssertEqual(event.pid, 4321)
        XCTAssertEqual(event.localizedName, "Calculator")
        XCTAssertEqual(event.eventType, .launched)
    }

    func test_wait_resolvesOnWildcard_whenBundleIdFilterIsNil() async throws {
        async let result = bridge.wait(event: .launched, bundleIdentifierFilter: nil, timeout: 5)
        await settle()
        fake.fireLaunched(bundleId: "com.example.random", pid: 9999, name: "Random")
        let event = try await result
        XCTAssertEqual(event.bundleIdentifier, "com.example.random")
        XCTAssertEqual(event.pid, 9999)
    }

    func test_wait_ignoresMismatchedBundleId() async {
        async let result = bridge.wait(
            event: .launched, bundleIdentifierFilter: "com.apple.calculator", timeout: 0.3)
        await settle()
        fake.fire(.launched, bundleId: "com.different.app", pid: 1234, name: "Different")
        do {
            _ = try await result
            XCTFail("Expected AppEventWaitTimeoutError")
        } catch is AppEventWaitTimeoutError {
            // expected — a mismatched event must not resolve the waiter
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_wait_dispatchesEachSupportedEventVariant() async throws {
        for event in AppEventType.allCases {
            let localBridge = NSWorkspaceEventBridge(notificationCenter: fake)
            async let result = localBridge.wait(
                event: event, bundleIdentifierFilter: nil, timeout: 5)
            await settle()
            fake.fire(event, bundleId: "com.apple.TextEdit", pid: 7, name: "TextEdit")
            let resolved = try await result
            XCTAssertEqual(resolved.eventType, event,
                           "bridge must resolve with the \(event.rawValue) event type")
        }
    }

    // MARK: - Error paths

    func test_wait_throwsWaitTimeoutError_whenNoEventFires() async {
        do {
            _ = try await bridge.wait(
                event: .terminated, bundleIdentifierFilter: nil, timeout: 0.1)
            XCTFail("Expected AppEventWaitTimeoutError")
        } catch let error as AppEventWaitTimeoutError {
            XCTAssertEqual(error.event, "terminated")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Leak prevention

    func test_wait_unregistersObserver_onTimeout() async {
        _ = try? await bridge.wait(
            event: .launched, bundleIdentifierFilter: nil, timeout: 0.05)
        XCTAssertEqual(fake.removeObserverCallCount, 1)
        XCTAssertEqual(fake.activeObserverCount, 0)
    }

    func test_wait_unregistersObserver_onResolve() async throws {
        async let result = bridge.wait(event: .launched, bundleIdentifierFilter: nil, timeout: 5)
        await settle()
        fake.fireLaunched(bundleId: "com.apple.calculator", pid: 1, name: "Calc")
        _ = try await result
        XCTAssertEqual(fake.removeObserverCallCount, 1)
        XCTAssertEqual(fake.activeObserverCount, 0)
    }

    func test_wait_stressTest_noLeakedObserversAfter100SequentialTimeouts() async {
        for _ in 0..<100 {
            _ = try? await bridge.wait(
                event: .launched, bundleIdentifierFilter: nil, timeout: 0.01)
        }
        XCTAssertEqual(fake.activeObserverCount, 0,
                       "no NSWorkspace observer may remain after 100 sequential timeouts")
        XCTAssertEqual(fake.removeObserverCallCount, 100)
    }

    // MARK: - Multiplexing & no double-subscription (Story Q4)

    func test_wait_multiplexesTwoCallers_ontoOneObserver() async throws {
        async let first = bridge.wait(
            event: .launched, bundleIdentifierFilter: "com.apple.calculator", timeout: 5)
        async let second = bridge.wait(
            event: .launched, bundleIdentifierFilter: "com.apple.calculator", timeout: 5)
        await settle()
        XCTAssertEqual(fake.observerCount(for: .launched), 1,
                       "two waiters on the same (event, bundle_id) must share one observer")
        fake.fireLaunched(bundleId: "com.apple.calculator", pid: 42, name: "Calculator")
        let a = try await first
        let b = try await second
        XCTAssertEqual(a.pid, 42)
        XCTAssertEqual(b.pid, 42)
        XCTAssertEqual(fake.activeObserverCount, 0)
    }

    func test_wait_activated_registersExactlyOneObserver_noDoubleSubscription() async throws {
        // STORY-018's bridge is deliberately separate from STORY-013's
        // frontmost-app observer (Q4); a single `activated` waiter must add
        // exactly one observer, never double-subscribing didActivateApplication.
        async let result = bridge.wait(
            event: .activated, bundleIdentifierFilter: "com.apple.TextEdit", timeout: 5)
        await settle()
        XCTAssertEqual(fake.observerCount(for: .activated), 1)
        fake.fire(.activated, bundleId: "com.apple.TextEdit", pid: 5, name: "TextEdit")
        _ = try await result
        XCTAssertEqual(fake.activeObserverCount, 0)
    }
}
