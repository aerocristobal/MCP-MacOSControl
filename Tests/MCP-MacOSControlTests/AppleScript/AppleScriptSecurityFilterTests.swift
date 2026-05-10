// STORY-006 — run_applescript MCP Tool
// COMPONENT: AppleScriptSecurityFilter

import XCTest
@testable import MacOSControlLib

final class AppleScriptSecurityFilterTests: XCTestCase {

    var filter: AppleScriptSecurityFilter!

    override func setUp() {
        super.setUp()
        filter = AppleScriptSecurityFilter()
    }

    // MARK: - Denylist coverage

    func test_validate_rejectsDoShellScript() {
        XCTAssertThrowsError(try filter.validate("do shell script \"ls\""))
    }

    func test_validate_rejectsDoShellScript_caseInsensitive() {
        XCTAssertThrowsError(try filter.validate("DO SHELL SCRIPT \"ls\""))
        XCTAssertThrowsError(try filter.validate("Do Shell Script \"ls\""))
    }

    func test_validate_rejectsDoShellScript_withExtraWhitespace() {
        XCTAssertThrowsError(try filter.validate("do  shell\tscript \"ls\""))
        XCTAssertThrowsError(try filter.validate("do\nshell\nscript \"ls\""))
    }

    func test_validate_rejectsLoadScript() {
        XCTAssertThrowsError(try filter.validate("load script file \"/tmp/x.scpt\""))
    }

    func test_validate_rejectsDoJavaScript() {
        XCTAssertThrowsError(
            try filter.validate("tell application \"Safari\" to do JavaScript \"alert(1)\" in document 1")
        )
    }

    func test_validate_rejectsSystemEventsTell() {
        XCTAssertThrowsError(
            try filter.validate("tell application \"System Events\" to keystroke \"x\"")
        )
    }

    func test_validate_rejectsPathTraversal() {
        XCTAssertThrowsError(try filter.validate("set f to POSIX file \"../../etc/passwd\""))
    }

    func test_validate_rejectsEtcPath() {
        XCTAssertThrowsError(try filter.validate("set f to POSIX file \"/etc/passwd\""))
    }

    func test_validate_rejectsPrivatePath() {
        XCTAssertThrowsError(try filter.validate("set f to POSIX file \"/private/var/foo\""))
    }

    func test_validate_rejectsSshPath() {
        XCTAssertThrowsError(try filter.validate("set f to POSIX file \"~/.ssh/id_rsa\""))
    }

    // MARK: - Allowlist (clean scripts pass)

    func test_validate_allowsCleanTellBlock() {
        XCTAssertNoThrow(try filter.validate("tell application \"Finder\" to get name of front window"))
    }

    func test_validate_allowsMultilineTellBlock() {
        let script = """
        tell application "TextEdit"
            set text of front document to "Hello"
        end tell
        """
        XCTAssertNoThrow(try filter.validate(script))
    }

    func test_validate_allowsArithmetic() {
        XCTAssertNoThrow(try filter.validate("return 1 + 1"))
    }

    // MARK: - Pattern stripping

    func test_validate_rejectsDoShellScript_evenAfterCommentStripping() {
        let script = "-- this comment mentions do shell script\ndo shell script \"ls\""
        XCTAssertThrowsError(try filter.validate(script))
    }

    func test_validate_doesNotRejectMatch_inStringLiteralOnly() {
        // Edge case: matching only inside a quoted string is a false positive.
        // Decision: filter is strict — reject anyway. Document the false-positive class.
        let script = "set x to \"do shell script is dangerous\""
        XCTAssertThrowsError(try filter.validate(script),
                             "filter is strict by design — see Open Question 1")
    }

    func test_validate_allowsMatchOnlyInsideStrippedComment() {
        // A bare comment with no real call-site after stripping should pass.
        let script = "-- do shell script appears in this comment but not in code\nreturn 1"
        XCTAssertNoThrow(try filter.validate(script))
    }

    // MARK: - Error envelope

    func test_validate_errorIncludesMatchedRuleName() {
        do {
            try filter.validate("do shell script \"x\"")
            XCTFail("expected throw")
        } catch let error as AppleScriptSecurityError {
            XCTAssertEqual(error.matchedRule, "do_shell_script")
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }
}
