import Foundation
@testable import MacOSControlLib

/// Deterministic `Clock`. By default each `sleep` advances virtual time by the
/// requested interval, so a poll loop reaches its timeout without real waiting.
/// Records every sleep so tests can assert "no trailing sleep after a match".
final class FakeClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date
    private(set) var sleepCalls: [Int] = []
    var autoAdvanceOnSleep = true

    init(start: Date = Date(timeIntervalSince1970: 0)) {
        self.current = start
    }

    func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func sleep(forMilliseconds milliseconds: Int) async {
        lock.lock()
        sleepCalls.append(milliseconds)
        if autoAdvanceOnSleep {
            current = current.addingTimeInterval(Double(milliseconds) / 1000.0)
        }
        lock.unlock()
    }

    func advance(_ seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(seconds)
    }
}
