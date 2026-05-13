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
        case .permissionDenied: return "PERMISSION_DENIED"
        case .windowNotFound: return "WINDOW_NOT_FOUND"
        case .mirroringNotRunning: return "MIRRORING_NOT_RUNNING"
        case .mirroringNotAvailable: return "MIRRORING_NOT_AVAILABLE"
        case .calibrationFailed: return "CALIBRATION_FAILED"
        case .invalidCoordinates: return "INVALID_COORDINATES"
        case .inputFailed: return "INPUT_FAILED"
        case .mirroringDisconnected: return "MIRRORING_DISCONNECTED"
        case .rateLimited: return "RATE_LIMITED"
        case .timeout: return "TIMEOUT"
        case .applescriptError: return "APPLESCRIPT_ERROR"
        case .executionTimeout: return "EXECUTION_TIMEOUT"
        case .securityPolicyViolation: return "SECURITY_POLICY_VIOLATION"
        case .automationPermissionRequired: return "AUTOMATION_PERMISSION_REQUIRED"
        case .noFrontmostApplication: return "NO_FRONTMOST_APPLICATION"
        case .accessibilityPermissionRequired: return "ACCESSIBILITY_PERMISSION_REQUIRED"
        }
    }

    public var description: String {
        switch self {
        case .permissionDenied(let detail): return "\(errorCode): \(detail)"
        case .windowNotFound(let detail): return "\(errorCode): \(detail)"
        case .mirroringNotRunning: return "\(errorCode): iPhone Mirroring is not running"
        case .mirroringNotAvailable: return "\(errorCode): iPhone Mirroring is not available"
        case .calibrationFailed(let detail): return "\(errorCode): \(detail)"
        case .invalidCoordinates(let detail): return "\(errorCode): \(detail)"
        case .inputFailed(let detail): return "\(errorCode): \(detail)"
        case .mirroringDisconnected: return "\(errorCode): iPhone Mirroring connection lost. Use iphone_reconnect to wait for recovery."
        case .rateLimited(let detail): return "\(errorCode): \(detail)"
        case .timeout(let detail): return "\(errorCode): \(detail)"
        case .applescriptError(let detail): return "\(errorCode): \(detail)"
        case .executionTimeout(let detail): return "\(errorCode): \(detail)"
        case .securityPolicyViolation(let detail): return "\(errorCode): \(detail)"
        case .automationPermissionRequired(let detail): return "\(errorCode): \(detail)"
        case .noFrontmostApplication:
            return "\(errorCode): No application currently has frontmost status. The system may be in Mission Control, the login screen, or another state without a foreground app."
        case .accessibilityPermissionRequired:
            return "\(errorCode): Accessibility permission required. Go to System Settings > Privacy & Security > Accessibility and enable permission for the app running this MCP server."
        }
    }

    public func toResult() -> CallTool.Result {
        .init(content: [.text(description)], isError: true)
    }
}
