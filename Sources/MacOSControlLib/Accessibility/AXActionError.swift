import Foundation
import MCP

public struct AXActionError: Error, CustomStringConvertible, LocalizedError {
    public enum Code: String, Sendable {
        case elementDisabled = "ax_element_disabled"
        case actionUnsupported = "ax_action_unsupported"
        case actionFailed = "ax_action_failed"
    }

    public let code: Code
    public let action: String
    public let detail: String
    public let underlyingCode: Int32

    public var errorCode: String { code.rawValue }

    public init(code: Code, action: String, detail: String, underlyingCode: Int32 = 0) {
        self.code = code
        self.action = action
        self.detail = detail
        self.underlyingCode = underlyingCode
    }

    public var description: String {
        "\(errorCode): action '\(action)' — \(detail)"
    }

    public var errorDescription: String? { description }

    public func toStructuredResult() -> CallTool.Result {
        var details: [String: Any] = ["action": action]
        if underlyingCode != 0 && code == .actionFailed {
            details["underlying_code"] = Int(underlyingCode)
        }
        return MCPErrorResponseBuilder.shared.build(
            code: errorCode,
            message: "action '\(action)' — \(detail)",
            details: details
        )
    }
}
