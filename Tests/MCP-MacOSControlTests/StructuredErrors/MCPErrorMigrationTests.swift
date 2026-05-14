// STORY: STORY-016 — Structured Error Response Contract
// COMPONENT: MCPError → Structured Result Migration (Scenario 7)

import XCTest
import MCP
@testable import MacOSControlLib

final class MCPErrorMigrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        _ = ErrorCodeRegistry.shared.allRegistrations().count
    }

    // MARK: - One-to-one snake_case mapping

    func test_permissionDenied_mapsToSnakeCaseCode() throws {
        let result = MacOSControlLib.MCPError.permissionDenied("AX permission required").toStructuredResult()
        let inner = try result.parseStructuredError()
        XCTAssertEqual(inner["code"] as? String, "permission_denied")
    }

    func test_windowNotFound_mapsToSnakeCaseCode() throws {
        let result = MacOSControlLib.MCPError.windowNotFound("Untitled").toStructuredResult()
        let inner = try result.parseStructuredError()
        XCTAssertEqual(inner["code"] as? String, "window_not_found")
    }

    func test_accessibilityPermissionRequired_mapsToSnakeCase_andCarriesDetails() throws {
        let result = MacOSControlLib.MCPError.accessibilityPermissionRequired.toStructuredResult()
        let inner = try result.parseStructuredError()
        XCTAssertEqual(inner["code"] as? String, "accessibility_permission_required")
        let details = inner["details"] as? [String: Any]
        XCTAssertNotNil(details?["recovery_hint"] as? String)
        XCTAssertNotNil(details?["system_settings_uri"] as? String)
    }

    // MARK: - Coverage — every MCPError case has a registered snake_case code

    func test_everyMCPErrorCase_producesIsErrorTrueAndRegisteredSnakeCaseCode() throws {
        let cases: [MacOSControlLib.MCPError] = [
            .permissionDenied("test"),
            .windowNotFound("test"),
            .mirroringNotRunning,
            .mirroringNotAvailable,
            .calibrationFailed("test"),
            .invalidCoordinates("test"),
            .inputFailed("test"),
            .mirroringDisconnected,
            .rateLimited("test"),
            .timeout("test"),
            .applescriptError("test"),
            .executionTimeout("test"),
            .securityPolicyViolation("test"),
            .automationPermissionRequired("test"),
            .noFrontmostApplication,
            .accessibilityPermissionRequired
        ]
        let snakeRegex = try NSRegularExpression(pattern: ErrorCodeRegistry.codeRegex)
        for error in cases {
            let result = error.toStructuredResult()
            XCTAssertEqual(result.isError, true, "\(error) failed to produce isError=true")
            let inner = try result.parseStructuredError()
            let code = try XCTUnwrap(inner["code"] as? String, "\(error) missing code")
            // snake_case shape
            let range = NSRange(code.startIndex..<code.endIndex, in: code)
            XCTAssertNotNil(snakeRegex.firstMatch(in: code, range: range),
                            "\(error) produced non-snake_case code: \(code)")
            // registered
            XCTAssertTrue(ErrorCodeRegistry.shared.isRegistered(code),
                          "\(error) produced unregistered code: \(code)")
        }
    }

    // MARK: - Legacy SCREAMING_SNAKE_CASE removal

    func test_descriptionFormat_isSnakeCaseColonMessage_notScreamingSnake() {
        // STORY-016: description shape is now "snake_case: message", never SCREAMING_SNAKE.
        XCTAssertTrue(MacOSControlLib.MCPError.permissionDenied("denied").description.hasPrefix("permission_denied:"))
        XCTAssertFalse(MacOSControlLib.MCPError.permissionDenied("denied").description.hasPrefix("PERMISSION_DENIED:"))
        XCTAssertFalse(MacOSControlLib.MCPError.windowNotFound("x").description.contains("WINDOW_NOT_FOUND"))
    }
}
