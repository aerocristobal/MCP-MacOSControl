import XCTest
import MCP
@testable import MacOSControlLib

final class MouseModuleTests: XCTestCase {
    func testClickScreenMissingParams() async throws {
        let result = try await MouseModule.handle(makeParams(name: "click_screen"))
        XCTAssertEqual(result?.isError, true)
    }

    func testMoveMouseMissingParams() async throws {
        let result = try await MouseModule.handle(makeParams(name: "move_mouse"))
        XCTAssertEqual(result?.isError, true)
    }

    func testDragMouseMissingParams() async throws {
        let result = try await MouseModule.handle(makeParams(name: "drag_mouse"))
        XCTAssertEqual(result?.isError, true)
    }

    func testScrollMissingParams() async throws {
        let result = try await MouseModule.handle(makeParams(name: "scroll"))
        XCTAssertEqual(result?.isError, true)
    }

    func testUnknownToolReturnsNil() async throws {
        let result = try await MouseModule.handle(makeParams(name: "unknown"))
        XCTAssertNil(result)
    }
}
