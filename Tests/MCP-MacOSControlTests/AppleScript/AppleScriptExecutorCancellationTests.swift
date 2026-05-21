// STORY-027 — AppleScriptExecutor cancellation path.
//
// Drives real osascript subprocesses to verify SIGTERM/SIGKILL behaviour.
// Gated by CI_MACOS_INTEGRATION=true alongside the existing
// AppleScriptExecutorIntegrationTests; on a developer laptop the gate is
// enabled when running this suite locally.

import XCTest
@testable import MacOSControlLib

final class AppleScriptExecutorCancellationTests: XCTestCase {

    private var executor: AppleScriptExecutor!

    override func setUp() {
        super.setUp()
        executor = AppleScriptExecutor()
    }

    private func skipUnlessIntegration() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CI_MACOS_INTEGRATION"] == "true",
            "integration test (real osascript)"
        )
    }

    func test_cancel_returnsCancelledResult_andKillsSubprocessQuickly() async throws {
        try skipUnlessIntegration()

        let token = CancellationToken()
        let context = ToolCallContext(requestId: "cancel-1", cancellation: token)

        // Cancel after a short interleave so the subprocess is already running.
        let runTask = Task<AppleScriptExecutionResult, Never> {
            // Script intentionally outlives any realistic test budget.
            return try! await executor.run("delay 60", timeout: 120, context: context)
        }

        try await Task.sleep(nanoseconds: 200_000_000)
        let cancelStart = Date()
        token.cancel()
        let result = await runTask.value
        let elapsedMs = Date().timeIntervalSince(cancelStart) * 1000

        guard case .failure(.cancelled) = result else {
            XCTFail("expected .failure(.cancelled), got \(result)")
            return
        }
        // SIGTERM should land within 500ms and the process should reap within
        // the SIGKILL escalation budget (+1000ms). Allow some headroom for CI.
        XCTAssertLessThan(elapsedMs, 1800,
                          "cancellation should reap subprocess within SIGTERM+SIGKILL budget")
    }

    func test_cancel_beforeRun_killsImmediately() async throws {
        try skipUnlessIntegration()

        let token = CancellationToken()
        token.cancel()  // pre-cancelled
        let context = ToolCallContext(requestId: "cancel-2", cancellation: token)

        let start = Date()
        let result = try await executor.run("delay 60", timeout: 120, context: context)
        let elapsedMs = Date().timeIntervalSince(start) * 1000

        guard case .failure(.cancelled) = result else {
            XCTFail("expected .failure(.cancelled), got \(result)")
            return
        }
        XCTAssertLessThan(elapsedMs, 200,
                          "pre-cancelled token must short-circuit before spawning anything")
    }

    func test_cancel_afterCompletion_isHarmless() async throws {
        try skipUnlessIntegration()

        let token = CancellationToken()
        let context = ToolCallContext(requestId: "cancel-3", cancellation: token)

        let result = try await executor.run("return \"ok\"", timeout: 5, context: context)
        token.cancel()  // late cancel — process already finished

        guard case .success(let stdout, _, _) = result else {
            XCTFail("expected success, got \(result)")
            return
        }
        XCTAssertEqual(stdout.trimmingCharacters(in: .whitespacesAndNewlines), "ok")
    }
}
