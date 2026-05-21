import Foundation
@testable import MacOSControlLib

/// Tool-layer fake. Records the most recent `wait` arguments and returns the
/// stubbed event or error so `WaitForUIEventToolTests` can drive the tool
/// without depending on the real actor's run-loop machinery.
final class FakeAXObserverManager: AXObserverManaging, @unchecked Sendable {

    var stubbedEvent: WaitForUIEvent?
    var stubbedError: Error?
    var stubbedCanSubscribe: Bool = true

    /// When set, `wait(...)` sleeps for this many nanoseconds while polling the
    /// supplied cancellation token. STORY-027 — lets tests assert that the
    /// tool propagates cancellation by cancelling the token mid-sleep.
    var simulatedDelayNanoseconds: UInt64 = 0

    private(set) var canSubscribeCallCount: Int = 0
    private(set) var waitCallCount: Int = 0
    private(set) var lastNotification: String?
    private(set) var lastPID: pid_t?
    private(set) var lastTimeout: TimeInterval?
    private(set) var lastCancellation: CancellationToken?
    private(set) var cancellationObserverCount: Int = 0

    func canSubscribe() async -> Bool {
        canSubscribeCallCount += 1
        return stubbedCanSubscribe
    }

    func wait(
        for notification: String,
        in pid: pid_t,
        timeout: TimeInterval,
        cancellation: CancellationToken?
    ) async throws -> WaitForUIEvent {
        waitCallCount += 1
        lastNotification = notification
        lastPID = pid
        lastTimeout = timeout
        lastCancellation = cancellation

        if let cancellation {
            cancellationObserverCount += 1
            cancellation.onCancel { /* observed */ }
        }

        if simulatedDelayNanoseconds > 0 {
            let step: UInt64 = 10_000_000
            var remaining = simulatedDelayNanoseconds
            while remaining > 0 {
                if cancellation?.isCancelled == true {
                    throw CancellationError()
                }
                let chunk = min(step, remaining)
                try? await Task.sleep(nanoseconds: chunk)
                remaining -= chunk
            }
        }

        if cancellation?.isCancelled == true {
            throw CancellationError()
        }
        if let stubbedError { throw stubbedError }
        return stubbedEvent ?? WaitForUIEvent(notification: notification)
    }
}
