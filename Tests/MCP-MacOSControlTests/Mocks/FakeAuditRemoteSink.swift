import Foundation
@testable import MacOSControlLib

/// Capture-spy remote sink. Records every shipped record and exposes
/// `ackDelayMs` and `shouldFail` knobs so tests can simulate slow or
/// failing destinations.
final class FakeAuditRemoteSink: AuditRemoteSink, @unchecked Sendable {

    private let lock = NSLock()
    private var _shipped: [AuditRecord] = []
    var ackDelayMs: Int = 0
    var shouldFail: Bool = false
    var shouldTimeout: Bool = false

    var shippedRecords: [AuditRecord] {
        lock.lock(); defer { lock.unlock() }
        return _shipped
    }

    func ship(_ record: AuditRecord, timeoutMs: Int) async throws -> Date {
        if ackDelayMs > 0 {
            try? await Task.sleep(nanoseconds: UInt64(ackDelayMs) * 1_000_000)
        }
        if shouldTimeout {
            throw AuditRemoteSinkError(.timeout)
        }
        if shouldFail {
            throw AuditRemoteSinkError(.transport("fake"))
        }
        lock.lock()
        _shipped.append(record)
        lock.unlock()
        return Date()
    }
}
