import Foundation
@testable import MacOSControlLib

final class MockDateProvider: DateProviding {
    var current: Date

    init(start: Date = Date(timeIntervalSince1970: 0)) {
        self.current = start
    }

    func now() -> Date { current }

    func advance(by seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }
}
