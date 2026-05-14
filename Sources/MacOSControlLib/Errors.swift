import Foundation
import MCP

public enum MCPError: Error, CustomStringConvertible {
    case permissionDenied(String)
    case windowNotFound(String)
    case mirroringNotRunning
    case mirroringNotAvailable
    case calibrationFailed(String)
    case invalidCoordinates(String)
    case inputFailed(String)
    case mirroringDisconnected
    case rateLimited(String)
    case timeout(String)
    case applescriptError(String)
    case executionTimeout(String)
    case securityPolicyViolation(String)
    case automationPermissionRequired(String)
    case noFrontmostApplication
    case accessibilityPermissionRequired

    public var errorCode: String {
        switch self {
        case .permissionDenied: return "permission_denied"
        case .windowNotFound: return "window_not_found"
        case .mirroringNotRunning: return "mirroring_not_running"
        case .mirroringNotAvailable: return "mirroring_not_available"
        case .calibrationFailed: return "calibration_failed"
        case .invalidCoordinates: return "invalid_coordinates"
        case .inputFailed: return "input_failed"
        case .mirroringDisconnected: return "mirroring_disconnected"
        case .rateLimited: return "rate_limited"
        case .timeout: return "timeout"
        case .applescriptError: return "applescript_error"
        case .executionTimeout: return "execution_timeout"
        case .securityPolicyViolation: return "security_policy_violation"
        case .automationPermissionRequired: return "automation_permission_required"
        case .noFrontmostApplication: return "no_frontmost_application"
        case .accessibilityPermissionRequired: return "accessibility_permission_required"
        }
    }

    public var message: String {
        switch self {
        case .permissionDenied(let detail): return detail
        case .windowNotFound(let detail): return detail
        case .mirroringNotRunning: return "iPhone Mirroring is not running"
        case .mirroringNotAvailable: return "iPhone Mirroring is not available"
        case .calibrationFailed(let detail): return detail
        case .invalidCoordinates(let detail): return detail
        case .inputFailed(let detail): return detail
        case .mirroringDisconnected: return "iPhone Mirroring connection lost. Use iphone_reconnect to wait for recovery."
        case .rateLimited(let detail): return detail
        case .timeout(let detail): return detail
        case .applescriptError(let detail): return detail
        case .executionTimeout(let detail): return detail
        case .securityPolicyViolation(let detail): return detail
        case .automationPermissionRequired(let detail): return detail
        case .noFrontmostApplication:
            return "No application currently has frontmost status. The system may be in Mission Control, the login screen, or another state without a foreground app."
        case .accessibilityPermissionRequired:
            return "Accessibility permission required. Go to System Settings > Privacy & Security > Accessibility and enable permission for the app running this MCP server."
        }
    }

    public var details: [String: Any]? {
        switch self {
        case .accessibilityPermissionRequired:
            return [
                "recovery_hint": "Open System Settings → Privacy & Security → Accessibility and enable the app running this MCP server, then restart the server.",
                "system_settings_uri": "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            ]
        case .automationPermissionRequired(let detail):
            return [
                "target_application": Self.extractTargetApplication(from: detail) ?? "",
                "recovery_hint": "Grant the host app permission to control \(Self.extractTargetApplication(from: detail) ?? "the target application") via System Settings → Privacy & Security → Automation."
            ]
        default:
            return nil
        }
    }

    public var description: String {
        "\(errorCode): \(message)"
    }

    public func toStructuredResult() -> CallTool.Result {
        MCPErrorResponseBuilder.shared.build(code: errorCode, message: message, details: details)
    }

    /// Parses an application name out of a detail string when the caller embedded one.
    /// Best-effort; returns nil if no recognizable pattern is found.
    private static func extractTargetApplication(from detail: String) -> String? {
        // Common shapes: "...for application 'Foo'", "Automation permission required for Foo:", "Foo denied permission"
        let patterns = [
            "for application ['\"]([^'\"]+)['\"]",
            "for application ([A-Z][\\w .]+?)(?:[:.]|$)",
            "^Automation permission [a-z ]+ for ([A-Z][\\w .]+?)(?:[:.]|$)"
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(detail.startIndex..<detail.endIndex, in: detail)
            if let match = regex.firstMatch(in: detail, options: [], range: range),
               match.numberOfRanges >= 2,
               let captureRange = Range(match.range(at: 1), in: detail) {
                return String(detail[captureRange]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
