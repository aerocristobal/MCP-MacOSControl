// STORY-006 — run_applescript MCP Tool
// COMPONENT: AutomationPermissionChecker
//
// NOTE: Tests for the static-extraction logic are pure unit tests. Tests that
// exercise AEDeterminePermissionToAutomateTarget are gated by
// CI_MACOS_INTEGRATION=true and require a real un-granted target on the runner.

import XCTest
@testable import MacOSControlLib

final class AutomationPermissionCheckerTests: XCTestCase {

    var checker: AutomationPermissionChecker!

    override func setUp() {
        super.setUp()
        checker = AutomationPermissionChecker()
    }

    // MARK: - Target extraction (pure unit tests)

    func test_extractTargetApps_findsSingleTellClause() {
        let apps = checker.extractTargetApps(from: "tell application \"Mail\" to get name")
        XCTAssertEqual(apps, ["Mail"])
    }

    func test_extractTargetApps_findsMultipleTellClauses() {
        let script = """
        tell application "Finder" to get name of front window
        tell application "Mail" to get name
        """
        let apps = checker.extractTargetApps(from: script)
        XCTAssertEqual(Set(apps), Set(["Finder", "Mail"]))
    }

    func test_extractTargetApps_returnsEmpty_forScriptWithoutTellClause() {
        let apps = checker.extractTargetApps(from: "return 1 + 1")
        XCTAssertTrue(apps.isEmpty)
    }

    func test_extractTargetApps_handlesQuotedAppNamesWithSpaces() {
        let apps = checker.extractTargetApps(from: "tell application \"Microsoft Word\" to quit")
        XCTAssertEqual(apps, ["Microsoft Word"])
    }

    func test_extractTargetApps_isCaseInsensitive() {
        let apps = checker.extractTargetApps(from: "TELL APPLICATION \"Mail\" TO get name")
        XCTAssertEqual(apps, ["Mail"])
    }

    func test_extractTargetApps_deduplicatesWithinScript() {
        let script = """
        tell application "Mail" to get name
        tell application "Mail" to count messages
        """
        let apps = checker.extractTargetApps(from: script)
        XCTAssertEqual(apps, ["Mail"])
    }

    // MARK: - Result mapping

    func test_check_returnsSkipped_whenNoStaticTellClause() {
        let result = checker.check(targetApps: [])
        XCTAssertEqual(result, .skipped)
    }

    // MARK: - Integration tests (real TCC state)

    func test_check_returnsDenied_forUngrantedApp() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CI_MACOS_INTEGRATION"] == "true",
            "integration test"
        )
        // Test runner must arrange a fixture app NOT pre-granted automation
        // permission and pass its name via CI_UNGRANTED_APP_NAME.
        guard let app = ProcessInfo.processInfo.environment["CI_UNGRANTED_APP_NAME"] else {
            throw XCTSkip("CI_UNGRANTED_APP_NAME not set")
        }
        let result = checker.check(targetApps: [app])
        if case .denied(let denied) = result {
            XCTAssertEqual(denied, app)
        } else {
            XCTFail("expected .denied, got \(result)")
        }
    }
}
