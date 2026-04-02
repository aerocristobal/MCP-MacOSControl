import XCTest
import MCP
@testable import MacOSControlLib

final class ScreenCaptureModuleTests: XCTestCase {
    // take_screenshot and take_screenshot_with_ocr have no required params,
    // so we can only test unknown tool rejection
    func testUnknownToolReturnsNil() async throws {
        let result = try await ScreenCaptureModule.handle(makeParams(name: "unknown"))
        XCTAssertNil(result)
    }
}
