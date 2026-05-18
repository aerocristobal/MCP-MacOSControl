import Foundation
@testable import MacOSControlLib

/// Scripted `ElementStateProbe`. Returns the queued results in order; once the
/// script is exhausted it keeps returning the final scripted value (so a
/// "stays disabled forever" timeout case needs only one trailing entry).
/// Matches the story §6 `FakeAXElementResolver.stub([.found(…), .notFound, …])`
/// intent without mocking the AX bridge.
final class FakeElementStateProbe: ElementStateProbe {
    private var queue: [ElementProbeResult]
    private let last: ElementProbeResult?
    private(set) var callCount = 0

    init(_ results: [ElementProbeResult]) {
        self.queue = results
        self.last = results.last
    }

    func probe() async -> ElementProbeResult {
        callCount += 1
        if !queue.isEmpty {
            return queue.removeFirst()
        }
        return last ?? .notFound
    }
}
