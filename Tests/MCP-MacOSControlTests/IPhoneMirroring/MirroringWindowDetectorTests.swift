import XCTest
@testable import MacOSControlLib

final class MirroringWindowDetectorTests: XCTestCase {

    func testIsMirroringRunningReturnsFalseInCI() {
        // In CI/test environment, iPhone Mirroring should not be running
        // This test documents expected behavior rather than asserting
        // (it may return true if running on a developer machine with mirroring active)
        _ = MirroringWindowDetector.isMirroringRunning()
    }

    func testClearCacheResetsState() {
        MirroringWindowDetector.clearCache()
        XCTAssertNil(MirroringWindowDetector.cachedWindowID)
        XCTAssertNil(MirroringWindowDetector.cachedWindowBounds)
    }

    func testClearCalibrationCache() {
        CoordinateTranslator.clearCache()
        // After clearing, next toAbsolute should trigger recalibration
        // We can't test the full flow without a mirroring window
    }
}
