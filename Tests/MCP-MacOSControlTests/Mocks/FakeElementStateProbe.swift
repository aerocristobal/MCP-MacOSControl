import Foundation
@testable import MacOSControlLib

/// Scripted `ElementStateProbe`. Returns the queued results in order; once the
/// script is exhausted it keeps returning the final scripted value (so a
/// "stays disabled forever" timeout case needs only one trailing entry).
/// Matches the story §6 `FakeAXElementResolver.stub([.found(…), .notFound, …])`
/// intent without mocking the AX bridge.
final class FakeElementStateProbe: ElementStateProbe, @unchecked Sendable {
    private var queue: [ElementProbeResult]
    private let last: ElementProbeResult?
    private(set) var callCount = 0

    /// STORY-027 — hook fired after each `probe()` call returns. Tests use this
    /// to inject cancellation between probes.
    var afterEachProbe: (() -> Void)?

    init(_ results: [ElementProbeResult]) {
        self.queue = results
        self.last = results.last
    }

    func probe() async -> ElementProbeResult {
        callCount += 1
        let result: ElementProbeResult
        if !queue.isEmpty {
            result = queue.removeFirst()
        } else {
            result = last ?? .notFound
        }
        afterEachProbe?()
        return result
    }
}
