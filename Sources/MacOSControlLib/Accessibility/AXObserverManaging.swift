import Foundation

/// Tool-layer seam over `AXObserverManager`. Lets `WaitForUIEventTool` be
/// constructed against a fake implementation in unit tests without requiring
/// the test to instantiate the real `AXObserverCreate`-backed bridge.
public protocol AXObserverManaging: AnyObject {
    func canSubscribe() async -> Bool

    /// STORY-027 — accept an optional `CancellationToken`. When the token is
    /// cancelled before the notification fires, the waiter is removed and the
    /// continuation resumes with `CancellationError`. The underlying AXObserver
    /// is destroyed if (and only if) this was the last waiter on its
    /// `(pid, notification)` tuple — same teardown contract as timeout.
    func wait(
        for notification: String,
        in pid: pid_t,
        timeout: TimeInterval,
        cancellation: CancellationToken?
    ) async throws -> WaitForUIEvent
}

public extension AXObserverManaging {
    /// Backwards-compatible convenience for call sites that aren't yet wired
    /// for cancellation. Equivalent to passing `cancellation: nil`.
    func wait(
        for notification: String,
        in pid: pid_t,
        timeout: TimeInterval
    ) async throws -> WaitForUIEvent {
        try await wait(for: notification, in: pid, timeout: timeout, cancellation: nil)
    }
}

extension AXObserverManager: AXObserverManaging {}
