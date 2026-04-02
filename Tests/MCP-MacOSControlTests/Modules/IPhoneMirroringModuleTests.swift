import XCTest
import MCP
@testable import MacOSControlLib

final class IPhoneMirroringModuleTests: XCTestCase {

    func testHas21Tools() {
        XCTAssertEqual(IPhoneMirroringModule.tools.count, 21)
    }

    func testToolNames() {
        let expected: Set<String> = [
            "iphone_status", "iphone_launch", "iphone_calibrate",
            "iphone_tap", "iphone_double_tap", "iphone_long_press",
            "iphone_swipe", "iphone_scroll",
            "iphone_type_text", "iphone_clear_text", "iphone_press_key",
            "iphone_home", "iphone_app_switcher", "iphone_spotlight",
            "iphone_screenshot", "iphone_screenshot_with_ocr",
            "iphone_analyze_screen_now", "iphone_analyze_with_llm",
            "iphone_open_app", "iphone_wait_for_text", "iphone_reconnect"
        ]
        let actual = Set(IPhoneMirroringModule.tools.map(\.name))
        XCTAssertEqual(actual, expected)
    }

    func testUnknownToolReturnsNil() async throws {
        let result = try await IPhoneMirroringModule.handle(makeParams(name: "unknown"))
        XCTAssertNil(result)
    }

    func testTapMissingParams() async throws {
        let result = try await IPhoneMirroringModule.handle(makeParams(name: "iphone_tap"))
        XCTAssertEqual(result?.isError, true)
    }

    func testDoubleTapMissingParams() async throws {
        let result = try await IPhoneMirroringModule.handle(makeParams(name: "iphone_double_tap"))
        XCTAssertEqual(result?.isError, true)
    }

    func testLongPressMissingParams() async throws {
        let result = try await IPhoneMirroringModule.handle(makeParams(name: "iphone_long_press"))
        XCTAssertEqual(result?.isError, true)
    }

    func testSwipeMissingParams() async throws {
        let result = try await IPhoneMirroringModule.handle(makeParams(name: "iphone_swipe"))
        XCTAssertEqual(result?.isError, true)
    }

    func testTypeTextMissingParams() async throws {
        let result = try await IPhoneMirroringModule.handle(makeParams(name: "iphone_type_text"))
        XCTAssertEqual(result?.isError, true)
    }

    func testPressKeyMissingParams() async throws {
        let result = try await IPhoneMirroringModule.handle(makeParams(name: "iphone_press_key"))
        XCTAssertEqual(result?.isError, true)
    }

    func testAnalyzeWithLlmMissingParams() async throws {
        let result = try await IPhoneMirroringModule.handle(makeParams(name: "iphone_analyze_with_llm"))
        XCTAssertEqual(result?.isError, true)
    }

    func testOpenAppMissingParams() async throws {
        let result = try await IPhoneMirroringModule.handle(makeParams(name: "iphone_open_app"))
        XCTAssertEqual(result?.isError, true)
    }

    func testWaitForTextMissingParams() async throws {
        let result = try await IPhoneMirroringModule.handle(makeParams(name: "iphone_wait_for_text"))
        XCTAssertEqual(result?.isError, true)
    }

    func testStatusReturnsResult() async throws {
        // iphone_status should always return a result (not nil), even when mirroring isn't running
        let result = try await IPhoneMirroringModule.handle(makeParams(name: "iphone_status"))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.isError, false) // status is informational, not an error
    }
}
