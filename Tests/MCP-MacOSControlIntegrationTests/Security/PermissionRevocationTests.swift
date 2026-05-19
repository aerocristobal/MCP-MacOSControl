// STORY-012 — End-to-End Integration Validation Suite
// SCENARIO: Mid-workflow permission revocation surfaces a structured error
// Re-validates: STORY-016, STORY-008
//
// This scenario is inherently environment-gated and, in the normal opt-in
// configuration, mutually exclusive with the suite's own precondition: the
// integration suite only runs when the runner *has* Accessibility permission
// (IntegrationTestCase skips otherwise), yet this scenario needs that
// permission to be *revoked mid-call*. macOS 13+ provides no supported
// non-interactive way to revoke a live TCC grant from within the process.
//
// Rather than fake a pass, we assert the durable parts of the contract that
// CAN be checked here — the error code is registered under STORY-016 and is
// classified environment-gated in the trigger manifest with a documented
// reason — then skip with that reason. The actual revocation→structured-error
// behavior is proven by STORY-016 unit tests; a real revocation is only
// exercised on a provisioned runner that sets MCP_ALLOW_TCC_REVOCATION=1 and
// supplies a signed helper (see docs/INTEGRATION-CI-SETUP.md).

import XCTest
import MCP
@testable import MacOSControlLib

final class PermissionRevocationTests: IntegrationTestCase {

    private let harness = IntegrationHarness()
    private let expectedCode = "accessibility_permission_required"

    func test_midWorkflowPermissionRevocation_surfacesStructuredError() async throws {
        // Durable invariant checks that do not require revoking permission.
        XCTAssertTrue(
            ErrorCodeRegistry.shared.isRegistered(expectedCode),
            "STORY-016 must register \(expectedCode)")
        let recipe = ErrorTriggerManifest.recipe(for: expectedCode)
        XCTAssertNotNil(recipe, "Manifest must cover \(expectedCode)")
        if case .environmentGated(let reason)? = recipe?.kind {
            XCTAssertFalse(reason.isEmpty,
                           "environment-gated reason must document why + where proven")
        } else {
            XCTFail("\(expectedCode) is expected to be environment-gated in the manifest")
        }

        guard ProcessInfo.processInfo.environment["MCP_ALLOW_TCC_REVOCATION"] == "1" else {
            throw XCTSkip("""
            Skipped: revoking a live Accessibility grant mid-call is not \
            supported non-interactively on macOS 13+, and the integration suite \
            itself requires that grant. Run on a provisioned runner with \
            MCP_ALLOW_TCC_REVOCATION=1 + a signed revocation helper \
            (docs/INTEGRATION-CI-SETUP.md). Contract proven by STORY-016 unit \
            tests; code is manifest-classed environment-gated.
            """)
        }

        // Provisioned-runner path: a workflow is in progress (it has called
        // wait_for_ui_event) when the helper revokes Accessibility.
        let revoker = TCCRevocationHelper()

        // Capture stderr across the window so we can verify the gherkin clause
        // "the server logs the revocation event with a structured log entry".
        // MCPLogger writes via fputs(..., stderr); ToolRouter.handle emits a
        // [WARN] entry for any failing tool invocation, which is the
        // observable structured trace of the revocation event.
        var inFlightResult: ToolResponse?
        var subsequentResult: ToolResponse?
        let captured = try await StderrCapture.capture {
            async let inFlight = harness.call("wait_for_ui_event", [
                "notification": .string("AXWindowCreated"),
                "application": .string("com.apple.TextEdit"),
                "timeout_seconds": .double(8)
            ])
            try? await Task.sleep(nanoseconds: 500_000_000)
            try revoker.revokeAccessibility()
            inFlightResult = try await inFlight

            // Server must not crash; a subsequent call returns the SAME
            // structured error, not a panic or a bare string.
            subsequentResult = try await harness.call("wait_for_ui_event", [
                "notification": .string("AXWindowCreated"),
                "application": .string("com.apple.TextEdit"),
                "timeout_seconds": .double(2)
            ])
        }

        let result = try XCTUnwrap(inFlightResult)
        XCTAssertTrue(result.isError, "Revocation must surface an error")
        XCTAssertEqual(result.errorCode, expectedCode,
                       "Must match the STORY-016 code")
        XCTAssertNotNil(result.message)

        let subsequent = try XCTUnwrap(subsequentResult)
        XCTAssertTrue(subsequent.isError)
        XCTAssertEqual(subsequent.errorCode, expectedCode,
                       "Every following call must return the same structured error")

        XCTAssertTrue(
            captured.contains("wait_for_ui_event") && captured.contains("failed"),
            """
            Server did not log a structured failure entry for the revocation \
            event. Expected a [WARN] line referencing the failing tool. \
            Captured stderr:
            \(captured)
            """)
    }
}

/// Thin wrapper over the signed revocation helper a provisioned runner installs.
/// Absent the helper this throws, which the gated test treats as an error (the
/// runner claimed support via the env flag but did not provide the helper).
private struct TCCRevocationHelper {
    enum HelperError: Error { case helperMissing }

    func revokeAccessibility() throws {
        let helper = "/usr/local/bin/mcp-tcc-revoke"
        guard FileManager.default.isExecutableFile(atPath: helper) else {
            throw HelperError.helperMissing
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: helper)
        p.arguments = ["Accessibility"]
        try p.run()
        p.waitUntilExit()
    }
}
