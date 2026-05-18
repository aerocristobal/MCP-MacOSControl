// STORY: STORY-018 — Wait for Application Lifecycle Event Tool
// COMPONENT: BundleIdentifierValidator

import XCTest
@testable import MacOSControlLib

final class BundleIdentifierValidatorTests: XCTestCase {

    func test_validate_acceptsReverseDNS() {
        XCTAssertNoThrow(try BundleIdentifierValidator.validate("com.apple.calculator"))
        XCTAssertNoThrow(try BundleIdentifierValidator.validate("io.example.long-name"))
        XCTAssertNoThrow(try BundleIdentifierValidator.validate("a.b"))
    }

    func test_validate_rejectsSpaces() {
        XCTAssertThrowsError(try BundleIdentifierValidator.validate("com apple calculator")) {
            XCTAssertTrue($0 is InvalidBundleIdentifierError)
        }
    }

    func test_validate_rejectsSingleToken() {
        XCTAssertThrowsError(try BundleIdentifierValidator.validate("calculator"))
    }

    func test_validate_rejectsEmpty() {
        XCTAssertThrowsError(try BundleIdentifierValidator.validate(""))
    }

    func test_validate_rejectsInvalidChars() {
        XCTAssertThrowsError(try BundleIdentifierValidator.validate("com.apple.calc/utility"))
    }
}
