import Foundation

/// Tool-layer seam over `NSWorkspaceEventBridge`. Lets `WaitForAppEventTool`
/// be constructed against a fake in unit tests without instantiating the real
/// `NSWorkspace`-backed observer. Parallel to STORY-008's `AXObserverManaging`.
public protocol NSWorkspaceEventManaging: AnyObject {
    /// STORY-027 — pass a `CancellationToken` to also race a caller-driven
    /// cancellation; on cancel the waiter is removed and the continuation
    /// resumes with `CancellationError`. Shared observers stay alive while
    /// other waiters remain.
    func wait(
        event: AppEventType,
        bundleIdentifierFilter: String?,
        timeout: TimeInterval,
        cancellation: CancellationToken?
    ) async throws -> AppLifecycleEvent
}

public extension NSWorkspaceEventManaging {
    /// Backwards-compatible convenience for call sites that aren't yet wired
    /// for cancellation.
    func wait(
        event: AppEventType,
        bundleIdentifierFilter: String?,
        timeout: TimeInterval
    ) async throws -> AppLifecycleEvent {
        try await wait(
            event: event,
            bundleIdentifierFilter: bundleIdentifierFilter,
            timeout: timeout,
            cancellation: nil
        )
    }
}

extension NSWorkspaceEventBridge: NSWorkspaceEventManaging {}
