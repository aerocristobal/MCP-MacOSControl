import Foundation
@testable import MacOSControlLib

/// Tool-layer fake. Records the most recent `wait` arguments and returns the
/// stubbed event or error so `WaitForAppEventToolTests` can drive the tool
/// without the real actor/notification machinery. Mirrors
/// `FakeAXObserverManager`.
final class FakeNSWorkspaceEventManaging: NSWorkspaceEventManaging {

    var stubbedEvent: AppLifecycleEvent?
    var stubbedError: Error?

    private(set) var waitCallCount = 0
    private(set) var lastEvent: AppEventType?
    private(set) var lastBundleIdentifierFilter: String?
    private(set) var lastFilterWasNil = false
    private(set) var lastTimeout: TimeInterval?

    func wait(
        event: AppEventType,
        bundleIdentifierFilter: String?,
        timeout: TimeInterval
    ) async throws -> AppLifecycleEvent {
        waitCallCount += 1
        lastEvent = event
        lastBundleIdentifierFilter = bundleIdentifierFilter
        lastFilterWasNil = bundleIdentifierFilter == nil
        lastTimeout = timeout
        if let stubbedError { throw stubbedError }
        return stubbedEvent ?? AppLifecycleEvent(
            eventType: event,
            bundleIdentifier: bundleIdentifierFilter,
            pid: 0,
            localizedName: nil
        )
    }
}
