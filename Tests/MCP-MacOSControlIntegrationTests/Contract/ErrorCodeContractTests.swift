// STORY-012 — End-to-End Integration Validation Suite
// SCENARIO: Structured-error contract honored across every error path
//
// Re-validates STORY-016 invariants for the *whole* registered code set:
//   1. Every registered code has a trigger recipe (fail fast otherwise).
//   2. Every forcible code, when triggered through the real ToolRouter, returns
//      the STORY-016 envelope: CallTool.Result.isError == true and a body of
//      { "ok": false, "error": { "code", "message", "details"? } } whose
//      error.code equals the registered code — never a bare string, never
//      isError:false.
//   3. Environment-gated codes are reported with their documented reason, not
//      faked into a pass.

import XCTest
import MCP
@testable import MacOSControlLib

final class ErrorCodeContractTests: IntegrationTestCase {

    private let harness = IntegrationHarness()

    func test_manifestCoversEveryRegisteredCode() throws {
        let registered = Set(ErrorCodeRegistry.shared.allRegistrations().map(\.code))
        let missing = registered
            .filter { ErrorTriggerManifest.recipe(for: $0) == nil }
            .sorted()

        XCTAssertTrue(
            missing.isEmpty,
            """
            ErrorTriggerManifest is missing recipes for registered codes: \
            \(missing). Add a .forcible or .environmentGated entry to \
            ErrorTriggerManifest.kinds for each — STORY-012 DoD requires 100% \
            coverage of ErrorCodeRegistry.
            """
        )
    }

    func test_everyForcibleCode_returnsStructuredErrorEnvelope() async throws {
        var checkedForcible = 0
        var gated: [(String, String)] = []

        for registration in ErrorCodeRegistry.shared.allRegistrations() {
            let code = registration.code
            guard let recipe = ErrorTriggerManifest.recipe(for: code) else {
                XCTFail("No trigger recipe for registered error_code: \(code)")
                continue
            }

            switch recipe.kind {
            case .environmentGated(let reason):
                gated.append((code, reason))

            case .forcible(let tool, let input):
                let response = try await harness.call(tool, input)

                XCTAssertTrue(
                    response.isError,
                    "\(code): \(tool) returned isError=false (raw=\(response.rawText))")
                XCTAssertEqual(
                    response.json["ok"] as? Bool, false,
                    "\(code): body.ok must be false (raw=\(response.rawText))")
                XCTAssertNotNil(
                    response.json["error"] as? [String: Any],
                    "\(code): body.error object missing (raw=\(response.rawText))")
                XCTAssertEqual(
                    response.errorCode, code,
                    "\(code): tool \(tool) produced error.code=\(response.errorCode ?? "nil")")
                XCTAssertNotNil(
                    response.message,
                    "\(code): error.message missing (raw=\(response.rawText))")
                XCTAssertFalse(
                    response.rawText.isEmpty,
                    "\(code): empty response body")
                checkedForcible += 1
            }
        }

        // Surface the environment-gated set so CI logs document exactly which
        // codes were proven elsewhere and why (the reason is the contract).
        if !gated.isEmpty {
            let lines = gated
                .sorted { $0.0 < $1.0 }
                .map { "  - \($0.0): \($0.1)" }
                .joined(separator: "\n")
            print("""
            [STORY-012] ErrorCodeContract — \(checkedForcible) codes forced & \
            verified; \(gated.count) environment-gated (proven elsewhere):
            \(lines)
            """)
        }

        XCTAssertGreaterThan(
            checkedForcible, 0,
            "Expected at least one forcible code to be exercised end-to-end.")
    }
}
