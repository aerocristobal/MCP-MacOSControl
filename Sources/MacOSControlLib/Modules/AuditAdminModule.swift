import Foundation
import MCP

/// STORY-024 — Administrative audit tools.
///
/// Two tools:
///   * `verify_audit_chain` — read-only chain integrity check; available
///     to any caller.
///   * `force_rotate_unacked` — destructive: rotates pending records to
///     archive (accepted log loss). Gated by
///     `MCP_MACOS_CONTROL_AUDIT_ADMIN_ENABLED=true`.
///
/// Both tools self-audit (the rotation tool records an
/// administrative_force_rotate_unacked event before acting).
public enum AuditAdminModule: ToolModule {

    /// Container injected once at server start. Holds the recorder,
    /// sweeper, and verifier so the tool handlers don't need to
    /// reconstruct them per call.
    public struct Wiring {
        public let auditor: AuditRecording
        public let sweeper: AuditRetentionSweeper
        public let verifier: AuditChainVerifier
        public let adminEnabled: Bool

        public init(
            auditor: AuditRecording,
            sweeper: AuditRetentionSweeper,
            verifier: AuditChainVerifier,
            adminEnabled: Bool
        ) {
            self.auditor = auditor
            self.sweeper = sweeper
            self.verifier = verifier
            self.adminEnabled = adminEnabled
        }
    }

    /// Process-wide wiring. Server.swift sets this once at startup.
    /// Nil in unit-test contexts that don't exercise the admin tools.
    public nonisolated(unsafe) static var wiring: Wiring?

    public static var tools: [Tool] {
        [
            Tool(
                name: "verify_audit_chain",
                description: """
                Verify the integrity of the audit log's hash chain across active and archived \
                records (STORY-024). Returns ok=true with total_checked when the chain is intact; \
                returns ok=false with first_break_at and a summary when a record's prev_hash or \
                record_hash does not match expected values. Read-only — does NOT repair the chain. \
                Treat any failure as SECURITY-CRITICAL; see docs/AUDIT-LOG-OPERATIONS.md for the \
                response playbook.
                """,
                inputSchema: jsonSchema(type: "object"),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "force_rotate_unacked",
                description: """
                ADMINISTRATIVE: Move audit records older than the retention window to archive \
                EVEN IF they have not yet been acknowledged by the remote sink. Bypasses \
                STORY-024's "pending records never rotate" rule and ACCEPTS the loss of any \
                records that have not made it off-host. Use only when a remote-sink outage \
                has lasted long enough that retaining the records is no longer operationally \
                viable. Logs its own administrative audit record before rotating. \
                Requires MCP_MACOS_CONTROL_AUDIT_ADMIN_ENABLED=true.
                """,
                inputSchema: jsonSchema(type: "object"),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: true,
                    idempotentHint: false
                )
            )
        ]
    }

    public static func handle(_ params: CallTool.Parameters, context: ToolCallContext) async throws -> CallTool.Result? {
        switch params.name {
        case "verify_audit_chain":
            return handleVerify()
        case "force_rotate_unacked":
            return handleForceRotate()
        default:
            return nil
        }
    }

    private static func handleVerify() -> CallTool.Result {
        guard let wiring = wiring else {
            return MCPErrorResponseBuilder.shared.build(
                code: "internal_error",
                message: "Audit subsystem not initialized."
            )
        }
        let report = wiring.verifier.verify()
        let payload: [String: Any] = [
            "ok": report.isValid,
            "total_checked": report.totalChecked,
            "first_break_at": report.firstBreakAt?.uuidString as Any,
            "summary": report.summary
        ]
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
        let text = String(data: data, encoding: .utf8) ?? "{}"
        return CallTool.Result(content: [.text(text)], isError: !report.isValid)
    }

    private static func handleForceRotate() -> CallTool.Result {
        guard let wiring = wiring else {
            return MCPErrorResponseBuilder.shared.build(
                code: "internal_error",
                message: "Audit subsystem not initialized."
            )
        }
        guard wiring.adminEnabled else {
            return MCPErrorResponseBuilder.shared.build(
                code: "audit_admin_disabled",
                message: "force_rotate_unacked requires MCP_MACOS_CONTROL_AUDIT_ADMIN_ENABLED=true."
            )
        }

        // Self-audit before rotating so the trail shows the rotation.
        _ = wiring.auditor.record(AuditRecordDraft(
            eventType: .administrativeForceRotateUnacked,
            scriptSha256: "",
            targetApps: [],
            filterDisposition: .notApplicable,
            executionOutcome: .administrative,
            durationMs: 0
        ))

        do {
            let result = try wiring.sweeper.forceRotateUnacked()
            let payload: [String: Any] = [
                "ok": true,
                "records_moved": result.recordsMoved,
                "chain_verified": result.chainVerified
            ]
            let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
            let text = String(data: data, encoding: .utf8) ?? "{}"
            return CallTool.Result(content: [.text(text)], isError: false)
        } catch {
            return MCPErrorResponseBuilder.shared.build(
                code: "internal_error",
                message: "force_rotate_unacked failed: \(error)"
            )
        }
    }
}
