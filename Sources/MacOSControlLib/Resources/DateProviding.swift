import Foundation

/// Clock indirection so the 100ms tree-read cache and 100ms publish debounce
/// can be exercised deterministically in tests without sleeping.
public protocol DateProviding: AnyObject {
    func now() -> Date
}

public final class SystemDateProvider: DateProviding {
    public init() {}
    public func now() -> Date { Date() }
}
