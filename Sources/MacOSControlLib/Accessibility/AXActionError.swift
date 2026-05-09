import Foundation
import MCP

public struct AXActionError: Error, CustomStringConvertible, LocalizedError {
    public enum Code: String, Sendable {
        case elementDisabled = "AX_ELEMENT_DISABLED"
        case actionUnsupported = "AX_ACTION_UNSUPPORTED"
        case actionFailed = "AX_ACTION_FAILED"
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

    public func toResult() -> CallTool.Result {
        .init(content: [.text(description)], isError: true)
    }
}
