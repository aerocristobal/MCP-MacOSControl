// STORY-027 — Cancellation path through RunAppleScriptTool.
//
// Exercises the tool layer with AppleScriptExecutorSpy (no real osascript)
// to verify that:
//   (1) when the caller cancels mid-execution the tool throws CancellationError
//       so the SDK suppresses the response,
//   (2) the audit log records execution_outcome: .cancelled, and
//   (3) a pre-cancelled context short-circuits before invoking the executor.

import XCTest
import MCP
@testable import MacOSControlLib

final class RunAppleScriptToolCancellationTests: XCTestCase {

    private var filterSpy: AppleScriptSecurityFilterSpy!
    private var executorSpy: AppleScriptExecutorSpy!
    private var permissionSpy: AutomationPermissionCheckerSpy!
    private var auditSpy: AuditRecorderSpy!
    private var tool: RunAppleScriptTool!

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

    func test_execute_propagatesCancellation_andWritesCancelledAudit() async throws {
        // Spy reports .cancelled as if the executor was killed mid-run.
        executorSpy.stubbedResult = .failure(.cancelled)
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("delay 10")])

        let context = ToolCallContext(
            requestId: "req-cancel",
            cancellation: CancellationToken()
        )

        do {
            _ = try await tool.execute(params, context: context)
            XCTFail("expected CancellationError to propagate")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("expected CancellationError, got \(error)")
        }

        XCTAssertEqual(executorSpy.runCallCount, 1)
        XCTAssertEqual(auditSpy.records.count, 1)
        XCTAssertEqual(auditSpy.records.first?.executionOutcome, .cancelled)
        XCTAssertEqual(auditSpy.records.first?.eventType, .applescriptExecute)
    }

    func test_execute_passesContextToExecutor() async throws {
        executorSpy.stubbedResult = .success(stdout: "ok", durationMs: 1)
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("return 1")])

        let token = CancellationToken()
        let context = ToolCallContext(requestId: "req-pass", cancellation: token)

        _ = try await tool.execute(params, context: context)

        XCTAssertNotNil(executorSpy.lastContext)
        XCTAssertEqual(executorSpy.lastContext?.requestId, "req-pass")
        XCTAssertTrue(executorSpy.lastContext?.cancellation === token,
                      "tool must forward the caller's CancellationToken verbatim")
    }

    func test_execute_preCancelledContext_shortCircuitsInExecutor() async throws {
        // The spy honours the token, so a pre-cancelled context produces a
        // cancelled result on first probe — verifying the tool wires the
        // token rather than papering over it.
        executorSpy.stubbedResult = .success(stdout: "should-not-happen", durationMs: 1)
        executorSpy.simulatedDelayNanoseconds = 100_000_000  // 100ms
        let params = makeParams(name: "run_applescript",
                                args: ["script": .string("delay 60")])

        let token = CancellationToken()
        token.cancel()
        let context = ToolCallContext(requestId: "req-pre", cancellation: token)

        do {
            _ = try await tool.execute(params, context: context)
            XCTFail("expected CancellationError")
        } catch is CancellationError {
            // expected
        }
        XCTAssertEqual(auditSpy.records.first?.executionOutcome, .cancelled)
    }
}
