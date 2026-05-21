import Foundation
@testable import MacOSControlLib

/// Tool-layer fake. Records the most recent `wait` arguments and returns the
/// stubbed event or error so `WaitForAppEventToolTests` can drive the tool
/// without the real actor/notification machinery. Mirrors
/// `FakeAXObserverManager`.
final class FakeNSWorkspaceEventManaging: NSWorkspaceEventManaging, @unchecked Sendable {

    var stubbedEvent: AppLifecycleEvent?
    var stubbedError: Error?

    /// STORY-027 — when set, `wait(...)` sleeps for this many nanoseconds while
    /// polling the supplied cancellation token. Lets tests cancel mid-wait and
    /// observe a `CancellationError` propagating up.
    var simulatedDelayNanoseconds: UInt64 = 0

    private(set) var waitCallCount = 0
    private(set) var lastEvent: AppEventType?
    private(set) var lastBundleIdentifierFilter: String?
    private(set) var lastFilterWasNil = false
    private(set) var lastTimeout: TimeInterval?
    private(set) var lastCancellation: CancellationToken?
    private(set) var cancellationObserverCount: Int = 0

    func wait(
        event: AppEventType,
        bundleIdentifierFilter: String?,
        timeout: TimeInterval,
        cancellation: CancellationToken?
    ) async throws -> AppLifecycleEvent {
        waitCallCount += 1
        lastEvent = event
        lastBundleIdentifierFilter = bundleIdentifierFilter
        lastFilterWasNil = bundleIdentifierFilter == nil
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
        return stubbedEvent ?? AppLifecycleEvent(
            eventType: event,
            bundleIdentifier: bundleIdentifierFilter,
            pid: 0,
            localizedName: nil
        )
    }
}
