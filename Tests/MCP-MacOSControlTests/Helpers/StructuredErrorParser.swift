import Foundation
import XCTest
import MCP
@testable import MacOSControlLib

/// Errors produced by parseStructuredError(). Helps tests distinguish between
/// "no content blocks" and "content was not valid JSON in the expected shape".
public enum StructuredErrorParseError: Error, CustomStringConvertible {
    case noTextContent
    case notJSON(String)
    case missingEnvelope(String)

    public var description: String {
        switch self {
        case .noTextContent:
            return "result has no .text content block"
        case .notJSON(let text):
            return "content text was not parseable JSON: \(text)"
        case .missingEnvelope(let text):
            return "JSON did not contain { ok: false, error: {...} }: \(text)"
        }
    }
}

extension CallTool.Result {
    /// Parses { "ok": false, "error": { code, message, details? } } and returns
    /// the inner "error" object. Throws if the content is not a structured error
    /// of the wrapped shape STORY-016 establishes.
    public func parseStructuredError() throws -> [String: Any] {
        var lastText: String? = nil
        for content in content {
            if case .text(let text, _, _) = content {
                lastText = text
                guard let data = text.data(using: .utf8) else { continue }
                guard let outer = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                guard let inner = outer["error"] as? [String: Any] else {
                    throw StructuredErrorParseError.missingEnvelope(text)
                }
                return inner
            }
        }
        if let lastText {
            throw StructuredErrorParseError.notJSON(lastText)
        }
        throw StructuredErrorParseError.noTextContent
    }
}
