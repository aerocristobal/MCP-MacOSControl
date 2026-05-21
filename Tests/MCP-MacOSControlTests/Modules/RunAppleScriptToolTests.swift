// STORY-006 + STORY-024 — run_applescript MCP Tool
// COMPONENT: RunAppleScriptTool
//
// XCTest mirror of the six BDD scenarios in
// Tests/MCP-MacOSControlTests/Features/story-006-run-applescript.feature plus
// cross-cutting audit assertions adapted to the STORY-024 record schema
// (event_type + filter_disposition + execution_outcome).

import XCTest
import MCP
@testable import MacOSControlLib

final class RunAppleScriptToolTests: XCTestCase {

    var filterSpy: AppleScriptSecurityFilterSpy!
    var executorSpy: AppleScriptExecutorSpy!
    var permissionSpy: AutomationPermissionCheckerSpy!
    var auditSpy: AuditRecorderSpy!
    var tool: RunAppleScriptTool!

    override func setUp() {
        super.setUp()
        filterSpy = AppleScriptSecurityFilterSpy()
        executorSpy = AppleScriptExecutorSpy()
        permissionSpy = AutomationPermissionCheckerSpy()
        auditSpy = AuditRecorderSpy()
        permissionSpy.stubbedResult = .skipped
        tool = RunAppleScriptTool(
            filter: filterSpy,
            permissionChecker: permissionSpy,
            executor: executorSpy,
            audit: auditSpy
        )
    }

    // MARK: - Scenario 1: Read-only happy path

    func test_execute_invokesExecutor_withProvidedScript() async throws {
        executorSpy.stubbedResult = .success(stdout: "Untitled", durationMs: 42)
        let script = "tell application \"Finder\" to get name of front window"
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string(script)])

        _ = try await tool.execute(params)

        XCTAssertEqual(executorSpy.lastScript, script)
        XCTAssertEqual(executorSpy.runCallCount, 1)
    }

    func test_execute_responseIncludesDurationMs() async throws {
        executorSpy.stubbedResult = .success(stdout: "Untitled", durationMs: 42)
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("return 1")])

        let result = try await tool.execute(params)

        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("\"duration_ms\""),
                      "expected duration_ms in response; got: \(text)")
        XCTAssertTrue(text.contains("42"),
                      "expected duration value 42; got: \(text)")
    }

    func test_execute_responseIncludesStdoutAsResult() async throws {
        executorSpy.stubbedResult = .success(stdout: "Untitled", durationMs: 42)
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("return 1")])

        let result = try await tool.execute(params)

        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("Untitled"),
                      "expected stdout in response; got: \(text)")
    }

    func test_execute_passesDefaultTimeout_whenOmitted() async throws {
        executorSpy.stubbedResult = .success(stdout: "", durationMs: 0)
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("return 1")])

        _ = try await tool.execute(params)

        XCTAssertEqual(executorSpy.lastTimeout, 30,
                       "default timeout per Open Question 3")
    }

    func test_execute_clampsTimeout_belowMinimum() async throws {
        executorSpy.stubbedResult = .success(stdout: "", durationMs: 0)
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("return 1"),
                                       "timeout_seconds": .int(0)])

        _ = try await tool.execute(params)

        XCTAssertEqual(executorSpy.lastTimeout, 1)
    }

    func test_execute_clampsTimeout_aboveMaximum() async throws {
        executorSpy.stubbedResult = .success(stdout: "", durationMs: 0)
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("return 1"),
                                       "timeout_seconds": .int(99999)])

        _ = try await tool.execute(params)

        XCTAssertEqual(executorSpy.lastTimeout, 300)
    }

    // MARK: - Output truncation (DoD: 1 MB cap, `truncated` flag in response)

    func test_execute_responseIncludesTruncatedFalse_forNormalOutput() async throws {
        executorSpy.stubbedResult = .success(stdout: "ok", durationMs: 1, truncated: false)
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("return 1")])

        let result = try await tool.execute(params)

        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("\"truncated\":false") || text.contains("\"truncated\": false"),
                      "expected truncated:false in response; got: \(text)")
    }

    func test_execute_responseIncludesTruncatedTrue_whenOutputCapped() async throws {
        executorSpy.stubbedResult = .success(stdout: "...", durationMs: 1, truncated: true)
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("get every message")])

        let result = try await tool.execute(params)

        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("\"truncated\":true") || text.contains("\"truncated\": true"),
                      "expected truncated:true in response when executor caps output; got: \(text)")
    }

    // MARK: - Scenario 2: State-mutating script

    func test_execute_returnsSuccess_forStateMutatingScript() async throws {
        executorSpy.stubbedResult = .success(stdout: "", durationMs: 100)
        let params = makeParams(name: "run_applescript", args: [
            "script": .string("tell application \"TextEdit\" to set text of front document to \"Hello\"")
        ])

        let result = try await tool.execute(params)

        XCTAssertFalse(result?.isError ?? true)
    }

    // MARK: - Scenario 3: Syntax error

    func test_execute_returnsAppleScriptError_forSyntaxError() async throws {
        executorSpy.stubbedResult = .failure(.scriptError(
            code: -2741,
            message: "Expected end of line but found unknown token"
        ))
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("tell application ???")])

        let result = try await tool.execute(params)

        XCTAssertTrue(result?.isError ?? false)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("applescript_error"))
        XCTAssertTrue(text.contains("-2741"),
                      "expected osascript error number; got: \(text)")
        XCTAssertTrue(text.contains("Expected end of line"),
                      "expected error message; got: \(text)")
    }

    // MARK: - Scenario 4: Timeout

    func test_execute_returnsTimeoutError_whenExecutorTimesOut() async throws {
        executorSpy.stubbedResult = .failure(.timeout(after: 5.0))
        let params = makeParams(name: "run_applescript", args: [
            "script": .string("delay 9999"),
            "timeout_seconds": .int(5)
        ])

        let result = try await tool.execute(params)

        XCTAssertTrue(result?.isError ?? false)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("execution_timeout"))
    }

    // MARK: - Scenario 5: Security rejection

    func test_execute_rejectsScript_withSecurityPolicyViolation() async throws {
        filterSpy.shouldReject = .doShellScript
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("do shell script \"rm -rf /tmp/x\"")])

        let result = try await tool.execute(params)

        XCTAssertTrue(result?.isError ?? false)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("security_policy_violation"))
    }

    func test_execute_doesNotInvokeExecutor_whenFilterRejects() async throws {
        filterSpy.shouldReject = .doShellScript
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("do shell script \"...\"")])

        _ = try await tool.execute(params)

        XCTAssertEqual(executorSpy.runCallCount, 0,
                       "executor must not run when filter rejects")
    }

    // MARK: - Scenario 6: Permission check

    func test_execute_returnsAutomationPermissionRequired_whenCheckerDenies() async throws {
        permissionSpy.stubbedResult = .denied(targetApp: "Mail")
        let params = makeParams(name: "run_applescript", args: [
            "script": .string("tell application \"Mail\" to get name")
        ])

        let result = try await tool.execute(params)

        XCTAssertTrue(result?.isError ?? false)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("automation_permission_required"))
        XCTAssertTrue(text.contains("Mail"),
                      "error must name the target application")
        XCTAssertTrue(text.contains("Privacy") || text.contains("Automation"),
                      "error must explain how to grant permission")
    }

    func test_execute_doesNotInvokeExecutor_whenPermissionDenied() async throws {
        permissionSpy.stubbedResult = .denied(targetApp: "Mail")
        let params = makeParams(name: "run_applescript", args: [
            "script": .string("tell application \"Mail\" to get name")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(executorSpy.runCallCount, 0,
                       "osascript must not be invoked after permission denial")
    }

    func test_execute_proceeds_whenPermissionGranted() async throws {
        permissionSpy.stubbedResult = .granted
        executorSpy.stubbedResult = .success(stdout: "Mail", durationMs: 12)
        let params = makeParams(name: "run_applescript", args: [
            "script": .string("tell application \"Mail\" to get name")
        ])

        let result = try await tool.execute(params)

        XCTAssertFalse(result?.isError ?? true)
        XCTAssertEqual(executorSpy.runCallCount, 1)
    }

    func test_execute_proceeds_whenScriptHasNoStaticTellClause() async throws {
        permissionSpy.stubbedResult = .skipped
        executorSpy.stubbedResult = .success(stdout: "1", durationMs: 1)
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("return 1 + 1")])

        let result = try await tool.execute(params)

        XCTAssertFalse(result?.isError ?? true)
        XCTAssertEqual(executorSpy.runCallCount, 1)
    }

    // MARK: - Audit (cross-cutting; STORY-024 schema)

    func test_execute_emitsAuditRecord_onSuccess() async throws {
        executorSpy.stubbedResult = .success(stdout: "ok", durationMs: 10)
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("return 1")])

        _ = try await tool.execute(params)

        XCTAssertEqual(auditSpy.records.count, 1)
        let r = auditSpy.records[0]
        XCTAssertEqual(r.eventType, .applescriptExecute)
        XCTAssertEqual(r.executionOutcome, .success)
        XCTAssertEqual(r.filterDisposition, .allowed)
        XCTAssertFalse(r.scriptSha256.isEmpty)
    }

    func test_execute_emitsAuditRecord_onSecurityRejection() async throws {
        filterSpy.shouldReject = .doShellScript
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("do shell script \"...\"")])

        _ = try await tool.execute(params)

        XCTAssertEqual(auditSpy.records.count, 1)
        let r = auditSpy.records[0]
        XCTAssertEqual(r.filterDisposition, .rejectedSecurity)
        XCTAssertEqual(r.executionOutcome, .notExecuted)
        XCTAssertEqual(r.rejectionReason, "do_shell_script")
    }

    func test_execute_emitsAuditRecord_onPermissionDenial() async throws {
        permissionSpy.stubbedResult = .denied(targetApp: "Mail")
        let params = makeParams(name: "run_applescript", args: [
            "script": .string("tell application \"Mail\" to get name")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(auditSpy.records.count, 1)
        let r = auditSpy.records[0]
        XCTAssertEqual(r.filterDisposition, .rejectedPermission)
        XCTAssertEqual(r.executionOutcome, .notExecuted)
        XCTAssertEqual(r.deniedApp, "Mail")
    }

    func test_execute_emitsAuditRecord_onTimeout() async throws {
        executorSpy.stubbedResult = .failure(.timeout(after: 5.0))
        let params = makeParams(name: "run_applescript", args: [
            "script": .string("delay 9999"),
            "timeout_seconds": .int(5)
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(auditSpy.records.count, 1)
        XCTAssertEqual(auditSpy.records[0].executionOutcome, .timeout)
    }

    func test_execute_emitsAuditRecord_onScriptError() async throws {
        executorSpy.stubbedResult = .failure(.scriptError(code: -2741, message: "boom"))
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("tell application ???")])

        _ = try await tool.execute(params)

        XCTAssertEqual(auditSpy.records.count, 1)
        XCTAssertEqual(auditSpy.records[0].executionOutcome, .scriptError)
        XCTAssertEqual(auditSpy.records[0].scriptErrorCode, -2741)
    }

    func test_execute_auditRecordContainsTargetApps() async throws {
        executorSpy.stubbedResult = .success(stdout: "", durationMs: 1)
        let params = makeParams(name: "run_applescript", args: [
            "script": .string("tell application \"Mail\" to get name")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(auditSpy.records.first?.targetAppsExtracted, ["Mail"])
    }

    func test_execute_auditChainPrevHashLinksRecords() async throws {
        executorSpy.stubbedResult = .success(stdout: "", durationMs: 1)
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("return 1")])
        _ = try await tool.execute(params)
        _ = try await tool.execute(params)

        XCTAssertEqual(auditSpy.records.count, 2)
        XCTAssertEqual(auditSpy.records[1].prevHash, auditSpy.records[0].recordHash)
    }

    // MARK: - Input validation

    func test_execute_rejectsMissingScriptArgument() async throws {
        let params = makeParams(name: "run_applescript", args: [:])

        let result = try await tool.execute(params)

        XCTAssertTrue(result?.isError ?? false)
        XCTAssertEqual(executorSpy.runCallCount, 0)
        XCTAssertEqual(filterSpy.validateCallCount, 0,
                       "filter should not run when input is invalid")
    }

    func test_execute_rejectsEmptyScriptArgument() async throws {
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("")])

        let result = try await tool.execute(params)

        XCTAssertTrue(result?.isError ?? false)
        XCTAssertEqual(executorSpy.runCallCount, 0)
    }
}
