import XCTest
import MCP
@testable import MacOSControlLib

final class CoordinateTranslatorTests: XCTestCase {

    func testMatchesIPhoneAspectRatioPortrait() {
        // 19.5:9 ratio in portrait (height > width)
        XCTAssertTrue(CoordinateTranslator.matchesIPhoneAspectRatio(width: 1320, height: 2868))
    }

    func testMatchesIPhoneAspectRatioLandscape() {
        // Same ratio but landscape
        XCTAssertTrue(CoordinateTranslator.matchesIPhoneAspectRatio(width: 2868, height: 1320))
    }

    func testRejectsSquareAspectRatio() {
        XCTAssertFalse(CoordinateTranslator.matchesIPhoneAspectRatio(width: 100, height: 100))
    }

    func testRejects16By9AspectRatio() {
        XCTAssertFalse(CoordinateTranslator.matchesIPhoneAspectRatio(width: 1920, height: 1080))
    }

    func testRejectsZeroDimensions() {
        XCTAssertFalse(CoordinateTranslator.matchesIPhoneAspectRatio(width: 0, height: 100))
        XCTAssertFalse(CoordinateTranslator.matchesIPhoneAspectRatio(width: 100, height: 0))
    }

    func testHeuristicContentRect() {
        let windowBounds = CGRect(x: 100, y: 200, width: 400, height: 800)
        let contentRect = CoordinateTranslator.heuristicContentRect(windowBounds: windowBounds)
        XCTAssertEqual(contentRect.minX, 100)
        XCTAssertEqual(contentRect.minY, 228) // 200 + 28pt title bar
        XCTAssertEqual(contentRect.width, 400)
        XCTAssertEqual(contentRect.height, 772) // 800 - 28
    }

    func testToNormalizedConversion() {
        let contentRect = CGRect(x: 100, y: 200, width: 400, height: 800)
        let (nx, ny) = CoordinateTranslator.toNormalized(absoluteX: 300, absoluteY: 600, contentRect: contentRect)
        XCTAssertEqual(nx, 0.5, accuracy: 0.001)
        XCTAssertEqual(ny, 0.5, accuracy: 0.001)
    }

    func testToNormalizedAtOrigin() {
        let contentRect = CGRect(x: 100, y: 200, width: 400, height: 800)
        let (nx, ny) = CoordinateTranslator.toNormalized(absoluteX: 100, absoluteY: 200, contentRect: contentRect)
        XCTAssertEqual(nx, 0.0, accuracy: 0.001)
        XCTAssertEqual(ny, 0.0, accuracy: 0.001)
    }

    func testToNormalizedAtMax() {
        let contentRect = CGRect(x: 100, y: 200, width: 400, height: 800)
        let (nx, ny) = CoordinateTranslator.toNormalized(absoluteX: 500, absoluteY: 1000, contentRect: contentRect)
        XCTAssertEqual(nx, 1.0, accuracy: 0.001)
        XCTAssertEqual(ny, 1.0, accuracy: 0.001)
    }

    func testEaseInOutAtBoundaries() {
        XCTAssertEqual(GestureEngine.easeInOut(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(GestureEngine.easeInOut(1.0), 1.0, accuracy: 0.001)
    }

    func testEaseInOutAtMidpoint() {
        XCTAssertEqual(GestureEngine.easeInOut(0.5), 0.5, accuracy: 0.001)
    }

    func testEaseInOutIsMonotonic() {
        var previous = 0.0
        for i in 1...100 {
            let t = Double(i) / 100.0
            let value = GestureEngine.easeInOut(t)
            XCTAssertGreaterThanOrEqual(value, previous, "Ease-in-out should be monotonically increasing")
            previous = value
        }
    }
}
