import XCTest
@testable import MacOSControlLib

final class AXElementValidatorTests: XCTestCase {

    func test_validate_passesWhenAttributesMatch() throws {
        let ref = AXElementReference(
            role: "AXButton",
            title: "OK",
            handle: .mock(UUID())
        )
        XCTAssertNoThrow(
            try AXElementValidator.validate(ref, expects: [.role: "AXButton", .title: "OK"])
        )
    }

    func test_validate_throwsWhenAttributeMissing() {
        let ref = AXElementReference(
            role: "AXButton",
            title: nil,
            handle: .mock(UUID())
        )
        XCTAssertThrowsError(
            try AXElementValidator.validate(ref, expects: [.title: "OK"])
        ) { error in
            XCTAssertTrue(error is AXResolutionError)
        }
    }

    func test_validate_throwsWhenAttributeMismatched() {
        let ref = AXElementReference(
            role: "AXButton",
            title: "Cancel",
            handle: .mock(UUID())
        )
        XCTAssertThrowsError(
            try AXElementValidator.validate(ref, expects: [.title: "OK"])
        ) { error in
            XCTAssertTrue(error is AXResolutionError)
        }
    }
}
