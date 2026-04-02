import XCTest
import MCP
@testable import MacOSControlLib

final class KeyboardModuleTests: XCTestCase {
    func testTypeTextMissingParams() async throws {
        let result = try await KeyboardModule.handle(makeParams(name: "type_text"))
        XCTAssertEqual(result?.isError, true)
    }

    func testKeyDownMissingParams() async throws {
        let result = try await KeyboardModule.handle(makeParams(name: "key_down"))
        XCTAssertEqual(result?.isError, true)
    }

    func testKeyUpMissingParams() async throws {
        let result = try await KeyboardModule.handle(makeParams(name: "key_up"))
        XCTAssertEqual(result?.isError, true)
    }

    func testPressKeysMissingParams() async throws {
        let result = try await KeyboardModule.handle(makeParams(name: "press_keys"))
        XCTAssertEqual(result?.isError, true)
    }

    func testUnknownToolReturnsNil() async throws {
        let result = try await KeyboardModule.handle(makeParams(name: "unknown"))
        XCTAssertNil(result)
    }
}
