import Foundation
@testable import MacOSControlLib

/// In-memory `AXObserverBridge` for `AXObserverManagerTests`. Records call
/// counts the lifecycle assertions rely on (create / remove / runloop source
/// removals) and exposes `fireNotification(_:for:)` so tests drive the event
/// loop deterministically.
final class FakeAXObserverBridge: AXObserverBridge {

    var isProcessTrusted: Bool = true

    /// Number of distinct `subscribe(...)` calls that produced a subscription.
    /// The manager's multiplex invariant means this should equal the number of
    /// (pid, notification) keys ever subscribed, NOT the number of MCP callers.
    private(set) var observerCreateCallCount: Int = 0

    /// Number of times a subscription's `cancel()` ran.
    private(set) var observerRemoveCallCount: Int = 0

    /// Surrogate for "CFRunLoopSource removed" — incremented from the same
    /// teardown path so the manager-leak-prevention assertion has something to
    /// look at. Real impl removes both in lock-step; we model the same coupling.
    var runLoopSourceRemovalCount: Int { observerRemoveCallCount }

    fileprivate final class FakeSubscription: AXObserverSubscription {
        let pid: pid_t
        let notification: String
        let handler: (WaitForUIEvent) -> Void
        weak var bridge: FakeAXObserverBridge?
        var isCancelled = false

        init(pid: pid_t, notification: String, handler: @escaping (WaitForUIEvent) -> Void, bridge: FakeAXObserverBridge) {
            self.pid = pid
            self.notification = notification
            self.handler = handler
            self.bridge = bridge
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            bridge?.didCancel(self)
        }
    }

    private var activeSubscriptions: [Key: FakeSubscription] = [:]

    private struct Key: Hashable {
        let pid: pid_t
        let notification: String
    }

    func subscribe(
        pid: pid_t,
        notification: String,
        handler: @escaping (WaitForUIEvent) -> Void
    ) throws -> AXObserverSubscription {
        let subscription = FakeSubscription(pid: pid, notification: notification, handler: handler, bridge: self)
        activeSubscriptions[Key(pid: pid, notification: notification)] = subscription
        observerCreateCallCount += 1
        return subscription
    }

    fileprivate func didCancel(_ subscription: FakeSubscription) {
        let key = Key(pid: subscription.pid, notification: subscription.notification)
        if activeSubscriptions[key] === subscription {
            activeSubscriptions.removeValue(forKey: key)
        }
        observerRemoveCallCount += 1
    }

    /// Drive the registered handler. Equivalent to a real `AXObserver`
    /// callback firing for the named (pid, notification) pair.
    func fireNotification(
        _ notification: String,
        for pid: pid_t,
        elementRole: String? = "AXWindow",
        elementTitle: String? = "Untitled",
        elementIdentifier: String? = nil
    ) {
        let key = Key(pid: pid, notification: notification)
        guard let subscription = activeSubscriptions[key] else { return }
        subscription.handler(WaitForUIEvent(
            notification: notification,
            elementRole: elementRole,
            elementTitle: elementTitle,
            elementIdentifier: elementIdentifier
        ))
    }

    /// Currently-active subscription count — used in lifecycle assertions to
    /// confirm the manager tore down every subscription on the firing /
    /// termination / timeout paths.
    var activeSubscriptionCount: Int { activeSubscriptions.count }
}
