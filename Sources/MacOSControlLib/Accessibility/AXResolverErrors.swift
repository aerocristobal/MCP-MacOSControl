import Foundation
import MCP

public struct AXNotFoundError: Error, CustomStringConvertible, LocalizedError {
    public let searchCriteria: String
    public let errorCode: String = "AX_NOT_FOUND"

    public init(searchCriteria: String) {
        self.searchCriteria = searchCriteria
    }

    public var description: String {
        "\(errorCode): No accessibility element matched \(searchCriteria)"
    }

    public var errorDescription: String? { description }

    public func toResult() -> CallTool.Result {
        .init(content: [.text(description)], isError: true)
    }
}

public struct AXResolutionError: Error, CustomStringConvertible, LocalizedError {
    public let detail: String
    public let errorCode: String = "AX_RESOLUTION_FAILED"
    let underlyingCode: Int32

    public init(detail: String, underlyingCode: Int32 = 0) {
        self.detail = detail
        self.underlyingCode = underlyingCode
    }

    public var description: String {
        "\(errorCode): \(detail)"
    }

    public var errorDescription: String? { description }

    public func toResult() -> CallTool.Result {
        .init(content: [.text(description)], isError: true)
    }
}
