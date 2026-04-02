import XCTest
import MCP
@testable import MacOSControlLib

final class AccessibilityModuleTests: XCTestCase {
    func testHas1Tool() {
        XCTAssertEqual(AccessibilityModule.tools.count, 1)
    }

    func testToolName() {
        XCTAssertEqual(AccessibilityModule.tools.first?.name, "accessibility_tree")
    }

    func testUnknownToolReturnsNil() async throws {
        let result = try await AccessibilityModule.handle(makeParams(name: "unknown"))
        XCTAssertNil(result)
    }
}
