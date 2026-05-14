import Foundation

public struct StructuredMCPError: Error, CustomStringConvertible {
    public let code: String
    public let message: String
    public let details: [String: Any]?

    public init(code: String, message: String, details: [String: Any]? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }

    public var description: String {
        "\(code): \(message)"
    }
}
