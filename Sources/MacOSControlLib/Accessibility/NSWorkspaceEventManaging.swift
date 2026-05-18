import Foundation

/// Tool-layer seam over `NSWorkspaceEventBridge`. Lets `WaitForAppEventTool`
/// be constructed against a fake in unit tests without instantiating the real
/// `NSWorkspace`-backed observer. Parallel to STORY-008's `AXObserverManaging`.
public protocol NSWorkspaceEventManaging: AnyObject {
    func wait(
        event: AppEventType,
        bundleIdentifierFilter: String?,
        timeout: TimeInterval
    ) async throws -> AppLifecycleEvent
}

extension NSWorkspaceEventBridge: NSWorkspaceEventManaging {}
