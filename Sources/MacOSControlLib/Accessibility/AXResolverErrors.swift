import Foundation
import MCP

public struct AXNotFoundError: Error, CustomStringConvertible, LocalizedError {
    public let searchCriteria: String
    public let errorCode: String = "ax_not_found"

    public init(searchCriteria: String) {
        self.searchCriteria = searchCriteria
    }

    public var description: String {
        "\(errorCode): No accessibility element matched \(searchCriteria)"
    }

    public var errorDescription: String? { description }

    public func toStructuredResult() -> CallTool.Result {
        MCPErrorResponseBuilder.shared.build(
            code: errorCode,
            message: "No accessibility element matched \(searchCriteria)",
            details: ["search_criteria": searchCriteria]
        )
    }
}

public struct AXResolutionError: Error, CustomStringConvertible, LocalizedError {
    public let detail: String
    public let errorCode: String = "ax_resolution_failed"
    let underlyingCode: Int32

    public init(detail: String, underlyingCode: Int32 = 0) {
        self.detail = detail
        self.underlyingCode = underlyingCode
    }

    public var description: String {
        "\(errorCode): \(detail)"
    }

    public var errorDescription: String? { description }

    public func toStructuredResult() -> CallTool.Result {
        var details: [String: Any] = [:]
        if underlyingCode != 0 {
            details["underlying_code"] = Int(underlyingCode)
        }
        return MCPErrorResponseBuilder.shared.build(
            code: errorCode,
            message: detail,
            details: details.isEmpty ? nil : details
        )
    }
}
