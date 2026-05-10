import XCTest
import CoreGraphics
@testable import MacOSControlLib

final class DisplayBoundsValidatorTests: XCTestCase {

    var validator: DisplayBoundsValidator!

    override func setUp() {
        super.setUp()
        validator = DisplayBoundsValidator(displays: [
            DisplayInfo(index: 0, frame: CGRect(x: 0,    y: 0, width: 1920, height: 1080)),
            DisplayInfo(index: 1, frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080))
        ])
    }

    func test_validate_passesForCoordsInsideDisplay0() {
        XCTAssertNoThrow(try validator.validate(x: 100, y: 100))
    }

    func test_validate_passesForCoordsInsideDisplay1() {
        XCTAssertNoThrow(try validator.validate(x: 2500, y: 100))
    }

    func test_validate_throwsForCoordsOutsideAllDisplays() {
        XCTAssertThrowsError(try validator.validate(x: 5000, y: 5000)) { error in
            guard let oob = error as? CoordinatesOutOfBoundsError else {
                return XCTFail("expected CoordinatesOutOfBoundsError, got \(error)")
            }
            XCTAssertEqual(oob.unionBounds.maxX, 3840)
            XCTAssertEqual(oob.unionBounds.maxY, 1080)
        }
    }

    func test_validate_throwsForNonFinite_x() {
        XCTAssertThrowsError(try validator.validate(x: .nan, y: 0)) { error in
            XCTAssertTrue(error is InvalidCoordinatesError)
        }
    }

    func test_validate_throwsForNonFinite_y() {
        XCTAssertThrowsError(try validator.validate(x: 0, y: .infinity)) { error in
            XCTAssertTrue(error is InvalidCoordinatesError)
        }
    }

    func test_validate_passesAtExactDisplayBoundary() {
        // Edge case: x=1920 is the boundary between display 0 and display 1.
        // Closed bounds on both sides mean it lies inside both displays' frames
        // and must validate.
        XCTAssertNoThrow(try validator.validate(x: 1920, y: 0))
    }

    func test_validate_passesAtExactUnionMaxCorner() {
        // (3840, 1080) is the bottom-right corner of display 1; closed-on-max
        // bounds keep it in.
        XCTAssertNoThrow(try validator.validate(x: 3840, y: 1080))
    }

    func test_unionBounds_isUnionOfAllDisplays() {
        let bounds = validator.unionBounds()
        XCTAssertEqual(bounds.minX, 0)
        XCTAssertEqual(bounds.minY, 0)
        XCTAssertEqual(bounds.maxX, 3840)
        XCTAssertEqual(bounds.maxY, 1080)
    }
}
