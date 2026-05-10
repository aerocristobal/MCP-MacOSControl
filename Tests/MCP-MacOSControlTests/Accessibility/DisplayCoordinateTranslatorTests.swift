import XCTest
import CoreGraphics
@testable import MacOSControlLib

final class DisplayCoordinateTranslatorTests: XCTestCase {

    var translator: DisplayCoordinateTranslator!

    override func setUp() {
        super.setUp()
        translator = DisplayCoordinateTranslator(displays: [
            DisplayInfo(index: 0, frame: CGRect(x: 0,    y: 0, width: 1920, height: 1080)),
            DisplayInfo(index: 1, frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080))
        ])
    }

    func test_toGlobal_addsDisplayOrigin() throws {
        let result = try translator.toGlobal(x: 100, y: 50, displayIndex: 1)
        XCTAssertEqual(result.x, 2020)
        XCTAssertEqual(result.y, 50)
    }

    func test_toGlobal_returnsInput_whenDisplayIndexNil() throws {
        let result = try translator.toGlobal(x: 100, y: 50, displayIndex: nil)
        XCTAssertEqual(result.x, 100)
        XCTAssertEqual(result.y, 50)
    }

    func test_toGlobal_throwsForUnknownDisplayIndex() {
        XCTAssertThrowsError(try translator.toGlobal(x: 100, y: 50, displayIndex: 99)) { error in
            guard let err = error as? UnknownDisplayIndexError else {
                return XCTFail("expected UnknownDisplayIndexError, got \(error)")
            }
            XCTAssertEqual(err.index, 99)
        }
    }

    func test_toGlobal_zeroOriginDisplay_returnsInputUnchanged() throws {
        let result = try translator.toGlobal(x: 50, y: 25, displayIndex: 0)
        XCTAssertEqual(result.x, 50)
        XCTAssertEqual(result.y, 25)
    }
}
