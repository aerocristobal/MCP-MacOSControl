import Foundation
import MCP

public final class RunAppleScriptTool {
    private let filter: AppleScriptSecurityFiltering
    private let permissionChecker: AutomationPermissionChecking
    private let executor: AppleScriptExecuting
    private let audit: AuditRecorder

    private static let defaultTimeoutSeconds = 30
    private static let minTimeoutSeconds = 1
    private static let maxTimeoutSeconds = 300

    public init(
        filter: AppleScriptSecurityFiltering,
        permissionChecker: AutomationPermissionChecking,
        executor: AppleScriptExecuting,
        audit: AuditRecorder
    ) {
        self.filter = filter
        self.permissionChecker = permissionChecker
        self.executor = executor
        self.audit = audit
    }

    public func execute(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]

        guard let script = args["script"]?.stringValue, !script.isEmpty else {
            return errorResult(
                code: "invalid_input",
                message: "run_applescript requires a non-empty 'script' argument"
            )
        }

        let timeoutSeconds = clampTimeout(args["timeout_seconds"]?.intValue ?? Self.defaultTimeoutSeconds)
        let auditFullSource = args["audit_full_source"]?.boolValue ?? false

        let scriptSha256 = ScriptHasher.sha256Hex(script)
        let recordedSource: String? = auditFullSource ? script : nil
        let targetApps = permissionChecker.extractTargetApps(from: script)

        // Phase 1: security filter
        do {
            try filter.validate(script)
        } catch let secError as AppleScriptSecurityError {
            audit.record(AuditRecord(
                timestamp: Date(),
                toolName: "run_applescript",
                scriptSha256: scriptSha256,
                scriptSource: recordedSource,
                outcome: .securityRejected(reason: secError.matchedRule),
                durationMs: 0,
                targetApps: targetApps
            ))
            return errorResult(
                code: "security_policy_violation",
                message: "\(secError.detail) (rule: \(secError.matchedRule))"
            )
        } catch {
            audit.record(AuditRecord(
                timestamp: Date(),
                toolName: "run_applescript",
                scriptSha256: scriptSha256,
                scriptSource: recordedSource,
                outcome: .securityRejected(reason: "unknown"),
                durationMs: 0,
                targetApps: targetApps
            ))
            return errorResult(
                code: "security_policy_violation",
                message: error.localizedDescription
            )
        }

        // Phase 2: TCC pre-flight
        switch permissionChecker.check(targetApps: targetApps) {
        case .denied(let app):
            audit.record(AuditRecord(
                timestamp: Date(),
                toolName: "run_applescript",
                scriptSha256: scriptSha256,
                scriptSource: recordedSource,
                outcome: .permissionDenied(app: app),
                durationMs: 0,
                targetApps: targetApps
            ))
            return errorResult(
                code: "automation_permission_required",
                message: "Automation permission required for \(app). Open System Settings > Privacy & Security > Automation and grant the MCP server permission to control \(app)."
            )
        case .granted, .skipped:
            break
        }

        // Phase 3: execute
        let executionResult: AppleScriptExecutionResult
        do {
            executionResult = try executor.run(script, timeout: TimeInterval(timeoutSeconds))
        } catch {
            audit.record(AuditRecord(
                timestamp: Date(),
                toolName: "run_applescript",
                scriptSha256: scriptSha256,
                scriptSource: recordedSource,
                outcome: .scriptError(code: 0),
                durationMs: 0,
                targetApps: targetApps
            ))
            return errorResult(
                code: "applescript_error",
                message: "executor failed: \(error.localizedDescription)"
            )
        }

        switch executionResult {
        case .success(let stdout, let durationMs, let truncated):
            audit.record(AuditRecord(
                timestamp: Date(),
                toolName: "run_applescript",
                scriptSha256: scriptSha256,
                scriptSource: recordedSource,
                outcome: .success,
                durationMs: durationMs,
                targetApps: targetApps
            ))
            return successResult(stdout: stdout, durationMs: durationMs, truncated: truncated)

        case .failure(.timeout(let after)):
            audit.record(AuditRecord(
                timestamp: Date(),
                toolName: "run_applescript",
                scriptSha256: scriptSha256,
                scriptSource: recordedSource,
                outcome: .timeout,
                durationMs: Int((after * 1000).rounded()),
                targetApps: targetApps
            ))
            return errorResult(
                code: "execution_timeout",
                message: "AppleScript execution exceeded the \(Int(after))-second timeout and was terminated."
            )

        case .failure(.scriptError(let code, let message)):
            audit.record(AuditRecord(
                timestamp: Date(),
                toolName: "run_applescript",
                scriptSha256: scriptSha256,
                scriptSource: recordedSource,
                outcome: .scriptError(code: code),
                durationMs: 0,
                targetApps: targetApps
            ))
            return errorResult(
                code: "applescript_error",
                message: "AppleScript error \(code): \(message)"
            )

        case .failure(.ioError(let detail)):
            audit.record(AuditRecord(
                timestamp: Date(),
                toolName: "run_applescript",
                scriptSha256: scriptSha256,
                scriptSource: recordedSource,
                outcome: .scriptError(code: 0),
                durationMs: 0,
                targetApps: targetApps
            ))
            return errorResult(
                code: "applescript_error",
                message: "osascript I/O failure: \(detail)"
            )
        }
    }

    private func clampTimeout(_ seconds: Int) -> Int {
        max(Self.minTimeoutSeconds, min(Self.maxTimeoutSeconds, seconds))
    }

    private func successResult(stdout: String, durationMs: Int, truncated: Bool) -> CallTool.Result {
        let payload: [String: Any] = [
            "ok": true,
            "result": stdout,
            "duration_ms": durationMs,
            "truncated": truncated
        ]
        let text = jsonString(payload) ?? "{\"ok\":true,\"result\":\"\",\"duration_ms\":\(durationMs)}"
        return .init(content: [.text(text)], isError: false)
    }

    private func errorResult(code: String, message: String) -> CallTool.Result {
        let payload: [String: Any] = [
            "ok": false,
            "error": [
                "code": code,
                "message": message
            ]
        ]
        let text = jsonString(payload) ?? "\(code): \(message)"
        return .init(content: [.text(text)], isError: true)
    }

    private func jsonString(_ payload: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
