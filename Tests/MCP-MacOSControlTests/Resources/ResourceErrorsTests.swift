// STORY: STORY-013 — MCP Resources for Ambient Context
// COMPONENT: MCPError additions
// Updated for STORY-016: codes are now snake_case; description has shape "code: message".

import XCTest
@testable import MacOSControlLib

final class ResourceErrorsTests: XCTestCase {

    func test_noFrontmostApplication_hasExpectedErrorCode() {
        XCTAssertEqual(MCPError.noFrontmostApplication.errorCode, "no_frontmost_application")
    }

    func test_noFrontmostApplication_descriptionIncludesErrorCode() {
        let description = MCPError.noFrontmostApplication.description
        XCTAssertTrue(description.hasPrefix("no_frontmost_application:"))
        XCTAssertTrue(description.contains("frontmost"))
    }

    func test_accessibilityPermissionRequired_hasExpectedErrorCode() {
        XCTAssertEqual(MCPError.accessibilityPermissionRequired.errorCode, "accessibility_permission_required")
    }

    func test_accessibilityPermissionRequired_descriptionExplainsHowToGrant() {
        let description = MCPError.accessibilityPermissionRequired.description
        XCTAssertTrue(description.contains("System Settings"))
        XCTAssertTrue(description.contains("Accessibility"))
    }

    func test_accessibilityPermissionRequired_detailsCarryRecoveryHintAndSettingsURI() {
        let details = MCPError.accessibilityPermissionRequired.details
        XCTAssertNotNil(details, "STORY-016: accessibility_permission_required must expose details for agents")
        XCTAssertNotNil(details?["recovery_hint"] as? String)
        XCTAssertNotNil(details?["system_settings_uri"] as? String)
        XCTAssertEqual(details?["system_settings_uri"] as? String,
                       "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }
}
