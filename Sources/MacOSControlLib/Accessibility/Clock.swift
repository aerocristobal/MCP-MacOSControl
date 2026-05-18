import Foundation

/// STORY-009 — minimal time abstraction so the poll loop's cadence and timeout
/// can be driven deterministically in tests (story §7: `Clock` / `FakeClock`).
public protocol Clock: Sendable {
    func now() -> Date
    func sleep(forMilliseconds milliseconds: Int) async
}

public struct SystemClock: Clock {
    public init() {}

    public func now() -> Date { Date() }

    public func sleep(forMilliseconds milliseconds: Int) async {
        let ns = UInt64(max(0, milliseconds)) * 1_000_000
        try? await Task.sleep(nanoseconds: ns)
    }
}
