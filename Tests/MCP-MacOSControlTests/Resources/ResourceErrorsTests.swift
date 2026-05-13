// STORY: STORY-013 — MCP Resources for Ambient Context
// COMPONENT: MCPError additions

import XCTest
@testable import MacOSControlLib

final class ResourceErrorsTests: XCTestCase {

    func test_noFrontmostApplication_hasExpectedErrorCode() {
        XCTAssertEqual(MCPError.noFrontmostApplication.errorCode, "NO_FRONTMOST_APPLICATION")
    }

    func test_noFrontmostApplication_descriptionIncludesErrorCode() {
        let description = MCPError.noFrontmostApplication.description
        XCTAssertTrue(description.hasPrefix("NO_FRONTMOST_APPLICATION:"))
        XCTAssertTrue(description.contains("frontmost"))
    }

    func test_accessibilityPermissionRequired_hasExpectedErrorCode() {
        XCTAssertEqual(MCPError.accessibilityPermissionRequired.errorCode, "ACCESSIBILITY_PERMISSION_REQUIRED")
    }

    func test_accessibilityPermissionRequired_descriptionExplainsHowToGrant() {
        let description = MCPError.accessibilityPermissionRequired.description
        XCTAssertTrue(description.contains("System Settings"))
        XCTAssertTrue(description.contains("Accessibility"))
    }
}
