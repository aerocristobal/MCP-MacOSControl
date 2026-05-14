import Foundation
import MCP

public final class MCPErrorResponseBuilder: @unchecked Sendable {

    public static let shared = MCPErrorResponseBuilder()

    private let registry: ErrorCodeRegistry

    public init(registry: ErrorCodeRegistry = .shared) {
        self.registry = registry
    }

    public func build(_ error: StructuredMCPError) -> CallTool.Result {
        build(code: error.code, message: error.message, details: error.details)
    }

    public func build(code: String, message: String, details: [String: Any]? = nil) -> CallTool.Result {
        #if DEBUG
        assertRegistered(code: code, details: details)
        #endif

        var errorObject: [String: Any] = [
            "code": code,
            "message": message
        ]
        if let details, !details.isEmpty {
            errorObject["details"] = details
        }

        let envelope: [String: Any] = [
            "ok": false,
            "error": errorObject
        ]

        let text = jsonString(envelope) ?? fallbackText(code: code, message: message)
        return .init(content: [.text(text)], isError: true)
    }

    public func buildFromUnknown(_ error: Error) -> CallTool.Result {
        let typeName = String(describing: type(of: error))
        let raw = String(describing: error)
        let scrubbed = scrubSensitiveDetails(raw)

        return build(
            code: "internal_error",
            message: scrubbed,
            details: [
                "swift_error_type": typeName
            ]
        )
    }

    // MARK: - Helpers

    private func jsonString(_ payload: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(
                withJSONObject: payload,
                options: [.sortedKeys]
              )
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func fallbackText(code: String, message: String) -> String {
        "{\"ok\":false,\"error\":{\"code\":\"\(code)\",\"message\":\"\(message.replacingOccurrences(of: "\"", with: "\\\""))\"}}"
    }

    private func scrubSensitiveDetails(_ text: String) -> String {
        let patterns = [
            "/Users/[^\\s\"',)]+",
            "/private/[^\\s\"',)]+",
            "/var/[^\\s\"',)]+",
            "/tmp/[^\\s\"',)]+"
        ]
        var scrubbed = text
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(scrubbed.startIndex..<scrubbed.endIndex, in: scrubbed)
            scrubbed = regex.stringByReplacingMatches(
                in: scrubbed,
                options: [],
                range: range,
                withTemplate: "<path-redacted>"
            )
        }
        return scrubbed
    }

    #if DEBUG
    private func assertRegistered(code: String, details: [String: Any]?) {
        guard let reg = registry.registration(for: code) else {
            assertionFailure("MCPErrorResponseBuilder: error code \"\(code)\" is not registered. Call ErrorCodeBootstrap.register() at server startup.")
            return
        }
        if let details {
            let registered = Set(reg.detailsSchema.keys)
            let provided = Set(details.keys)
            let extras = provided.subtracting(registered)
            if !extras.isEmpty {
                assertionFailure("MCPErrorResponseBuilder: error code \"\(code)\" provided details keys \(extras.sorted()) not declared in registry schema \(reg.detailsSchema.keys.sorted()).")
            }
        }
    }
    #endif
}
