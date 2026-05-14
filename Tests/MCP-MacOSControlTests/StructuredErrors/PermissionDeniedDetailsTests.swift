// STORY: STORY-016 — Structured Error Response Contract
// COMPONENT: accessibility_permission_required details (Scenario 3)

import XCTest
import MCP
@testable import MacOSControlLib

final class PermissionDeniedDetailsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        _ = ErrorCodeRegistry.shared.allRegistrations().count
    }

    func test_accessibilityPermissionRequired_includesRecoveryHintInDetails() throws {
        let result = MacOSControlLib.MCPError.accessibilityPermissionRequired.toStructuredResult()
        let inner = try result.parseStructuredError()
        let details = try XCTUnwrap(inner["details"] as? [String: Any])
        let hint = try XCTUnwrap(details["recovery_hint"] as? String)
        // Hint should mention System Settings + Accessibility so an agent can read it
        // back to the user without further processing.
        XCTAssertTrue(hint.contains("System Settings"),
                      "recovery_hint must reference 'System Settings'; got: \(hint)")
        XCTAssertTrue(hint.contains("Accessibility"),
                      "recovery_hint must reference 'Accessibility'; got: \(hint)")
    }

    func test_accessibilityPermissionRequired_includesSystemSettingsURIInDetails() throws {
        let result = MacOSControlLib.MCPError.accessibilityPermissionRequired.toStructuredResult()
        let inner = try result.parseStructuredError()
        let details = try XCTUnwrap(inner["details"] as? [String: Any])
        let uri = try XCTUnwrap(details["system_settings_uri"] as? String)
        XCTAssertTrue(uri.hasPrefix("x-apple.systempreferences:"),
                      "system_settings_uri must be a System Settings deep link; got: \(uri)")
        XCTAssertTrue(uri.contains("Privacy_Accessibility"),
                      "URI must target the Accessibility pane; got: \(uri)")
    }

    func test_automationPermissionRequired_includesTargetApplicationInDetails() throws {
        let result = MacOSControlLib.MCPError.automationPermissionRequired(
            "Automation permission required for application 'Mail'"
        ).toStructuredResult()
        let inner = try result.parseStructuredError()
        let details = try XCTUnwrap(inner["details"] as? [String: Any])
        XCTAssertEqual(details["target_application"] as? String, "Mail",
                       "details.target_application must surface the target app name")
        XCTAssertNotNil(details["recovery_hint"] as? String,
                        "details.recovery_hint must describe how to grant Automation permission")
    }
}
