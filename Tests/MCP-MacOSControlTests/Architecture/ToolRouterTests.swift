import XCTest
import MCP
@testable import MacOSControlLib

final class ToolRouterTests: XCTestCase {
    func testAllToolsReturns61Tools() {
        XCTAssertEqual(ToolRouter.allTools.count, 61)
    }

    func testAllToolNamesAreUnique() {
        let names = ToolRouter.allTools.map(\.name)
        XCTAssertEqual(Set(names).count, names.count, "Duplicate tool names found")
    }

    func testUnknownToolReturnsError() async throws {
        let params = makeParams(name: "nonexistent_tool")
        let result = try await ToolRouter.handle(params)
        let text = extractText(from: result)
        XCTAssertTrue(text?.contains("Unknown tool") == true)
    }

    func testDispatchesToMouseModule() async throws {
        // click_screen with missing params should return MouseModule's error, not "Unknown tool"
        let params = makeParams(name: "click_screen")
        let result = try await ToolRouter.handle(params)
        XCTAssertEqual(result.isError, true)
        let text = extractText(from: result)
        XCTAssertTrue(text?.contains("x and y") == true, "Expected MouseModule param error, got: \(text ?? "nil")")
    }

    func testDispatchesToKeyboardModule() async throws {
        let params = makeParams(name: "type_text")
        let result = try await ToolRouter.handle(params)
        XCTAssertEqual(result.isError, true)
        let text = extractText(from: result)
        XCTAssertTrue(text?.contains("text required") == true)
    }

    func testDispatchesToVisionModule() async throws {
        let params = makeParams(name: "classify_image")
        let result = try await ToolRouter.handle(params)
        XCTAssertEqual(result.isError, true)
        let text = extractText(from: result)
        XCTAssertTrue(text?.contains("image_data") == true)
    }

    func testDispatchesToAccessibilityModule() async throws {
        // accessibility_tree with no params should succeed (returns frontmost app or permission error)
        let params = makeParams(name: "accessibility_tree")
        let result = try await ToolRouter.handle(params)
        XCTAssertNotNil(result)
        // Should NOT be "Unknown tool"
        let text = extractText(from: result)
        XCTAssertFalse(text?.contains("Unknown tool") == true)
    }

    func testDispatchesToIPhoneMirroringModule() async throws {
        // iphone_tap with missing params should return IPhoneMirroringModule's error, not "Unknown tool"
        let params = makeParams(name: "iphone_tap")
        let result = try await ToolRouter.handle(params)
        XCTAssertEqual(result.isError, true)
        let text = extractText(from: result)
        XCTAssertFalse(text?.contains("Unknown tool") == true, "Expected IPhoneMirroringModule param error, got: \(text ?? "nil")")
    }
}
