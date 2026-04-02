import XCTest
@testable import MacOSControlLib

final class RateLimiterTests: XCTestCase {
    override func setUp() {
        super.setUp()
        RateLimiter.reset()
    }

    func testFirstCallAllowed() throws {
        XCTAssertNoThrow(try RateLimiter.checkInputAllowed())
    }

    func testMultipleCallsWithinRateAllowed() throws {
        for _ in 0..<5 {
            XCTAssertNoThrow(try RateLimiter.checkInputAllowed())
        }
    }

    func testResetClearsState() throws {
        // Use some tokens
        for _ in 0..<5 {
            try RateLimiter.checkInputAllowed()
        }
        RateLimiter.reset()
        // Should work again after reset
        XCTAssertNoThrow(try RateLimiter.checkInputAllowed())
    }
}
