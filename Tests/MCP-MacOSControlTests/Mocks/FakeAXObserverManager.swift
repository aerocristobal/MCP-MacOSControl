import Foundation
@testable import MacOSControlLib

/// Tool-layer fake. Records the most recent `wait` arguments and returns the
/// stubbed event or error so `WaitForUIEventToolTests` can drive the tool
/// without depending on the real actor's run-loop machinery.
final class FakeAXObserverManager: AXObserverManaging {

    var stubbedEvent: WaitForUIEvent?
    var stubbedError: Error?
    var stubbedCanSubscribe: Bool = true

    private(set) var canSubscribeCallCount: Int = 0
    private(set) var waitCallCount: Int = 0
    private(set) var lastNotification: String?
    private(set) var lastPID: pid_t?
    private(set) var lastTimeout: TimeInterval?

    func canSubscribe() async -> Bool {
        canSubscribeCallCount += 1
        return stubbedCanSubscribe
    }

    func wait(
        for notification: String,
        in pid: pid_t,
        timeout: TimeInterval
    ) async throws -> WaitForUIEvent {
        waitCallCount += 1
        lastNotification = notification
        lastPID = pid
        lastTimeout = timeout
        if let stubbedError { throw stubbedError }
        return stubbedEvent ?? WaitForUIEvent(notification: notification)
    }
}
