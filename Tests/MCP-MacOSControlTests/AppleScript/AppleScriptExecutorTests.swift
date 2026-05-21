// STORY-006 — run_applescript MCP Tool
// COMPONENT: AppleScriptExecutor
//
// NOTE: These tests invoke the real osascript binary. They are gated by
// CI_MACOS_INTEGRATION=true. Pure-unit coverage of the tool layer uses
// AppleScriptExecutorSpy — see RunAppleScriptToolTests.

import XCTest
@testable import MacOSControlLib

final class AppleScriptExecutorIntegrationTests: XCTestCase {

    var executor: AppleScriptExecutor!

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

    func test_run_returnsStdout_forSimpleExpression() async throws {
        try skipUnlessIntegration()
        let result = try await executor.run("return 1 + 1", timeout: 5)
        guard case .success(let stdout, _, let truncated) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertEqual(stdout.trimmingCharacters(in: .whitespacesAndNewlines), "2")
        XCTAssertFalse(truncated)
    }

    func test_run_returnsScriptError_forSyntaxError() async throws {
        try skipUnlessIntegration()
        let result = try await executor.run("this is not valid applescript", timeout: 5)
        guard case .failure(let error) = result,
              case .scriptError(let code, _) = error else {
            return XCTFail("expected scriptError, got \(result)")
        }
        XCTAssertNotEqual(code, 0)
    }

    func test_run_terminatesProcess_afterTimeout() async throws {
        try skipUnlessIntegration()
        let start = Date()
        let result = try await executor.run("delay 30", timeout: 1)
        let elapsed = Date().timeIntervalSince(start)

        guard case .failure(.timeout) = result else {
            return XCTFail("expected timeout, got \(result)")
        }
        XCTAssertLessThan(elapsed, 3.0,
                          "should terminate near timeout, not run full delay")
    }
}
