import Foundation

/// Tool-layer seam over `AXObserverManager`. Lets `WaitForUIEventTool` be
/// constructed against a fake implementation in unit tests without requiring
/// the test to instantiate the real `AXObserverCreate`-backed bridge.
public protocol AXObserverManaging: AnyObject {
    func canSubscribe() async -> Bool
    func wait(
        for notification: String,
        in pid: pid_t,
        timeout: TimeInterval
    ) async throws -> WaitForUIEvent
}

extension AXObserverManager: AXObserverManaging {}
