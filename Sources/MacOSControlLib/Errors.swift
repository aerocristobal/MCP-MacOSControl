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

    public var errorCode: String {
        switch self {
        case .permissionDenied: return "PERMISSION_DENIED"
        case .windowNotFound: return "WINDOW_NOT_FOUND"
        case .mirroringNotRunning: return "MIRRORING_NOT_RUNNING"
        case .mirroringNotAvailable: return "MIRRORING_NOT_AVAILABLE"
        case .calibrationFailed: return "CALIBRATION_FAILED"
        case .invalidCoordinates: return "INVALID_COORDINATES"
        case .inputFailed: return "INPUT_FAILED"
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
        }
    }

    public func toResult() -> CallTool.Result {
        .init(content: [.text(description)], isError: true)
    }
}
