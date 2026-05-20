// STORY-012 — End-to-End Integration Validation Suite
// COMPONENT: Ergonomic adapter over the real tool dispatch path.
//
// The story's scaffolds assumed `MCPServer.makeForIntegrationTests()` and
// `server.callTool(_:input:)` returning a typed response with `.content[...]`,
// `.errorCode`, `.message`. None of that exists. The shipped surface is
// `ToolRouter.handle(_ params: CallTool.Parameters) -> CallTool.Result`, where
// the result carries a single JSON `.text` content and an `isError` flag, and
// errors follow the STORY-016 envelope `{ "ok": false,
// "error": { "code", "message", "details"? } }`. This adapter is the only place
// that knows that, so scenarios stay readable.

import Foundation
import XCTest
import MCP
@testable import MacOSControlLib

/// Parsed view of a `CallTool.Result`.
struct ToolResponse {
    /// The decoded JSON body (the tool's single text content).
    let json: [String: Any]
    /// `CallTool.Result.isError ?? false`.
    let isError: Bool
    /// Raw JSON text, for diagnostics.
    let rawText: String

    /// STORY-016 error code (`error.code`), when this is an error envelope.
    var errorCode: String? { (json["error"] as? [String: Any])?["code"] as? String }
    /// STORY-016 error message.
    var message: String? { (json["error"] as? [String: Any])?["message"] as? String }
    /// STORY-016 error details.
    var details: [String: Any]? { (json["error"] as? [String: Any])?["details"] as? [String: Any] }

    /// Convenience: did the body carry the success sentinel `"ok": true`.
    var ok: Bool { (json["ok"] as? Bool) ?? false }

    func string(_ key: String) -> String? { json[key] as? String }
    func array(_ key: String) -> [Any]? { json[key] as? [Any] }
}

/// Drives real tools through `ToolRouter`. No mocks — integration by definition.
final class IntegrationHarness {

    @discardableResult
    func call(_ name: String, _ args: [String: Value] = [:]) async throws -> ToolResponse {
        let params = CallTool.Parameters(name: name, arguments: args.isEmpty ? nil : args)
        let result = try await ToolRouter.handle(params)
        return Self.parse(result)
    }

    /// Runs `name` and asserts a non-error response, returning it for further
    /// assertions. Fails the calling test with the tool's error envelope if it
    /// errored.
    @discardableResult
    func require(
        _ name: String,
        _ args: [String: Value] = [:],
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> ToolResponse {
        let response = try await call(name, args)
        if response.isError {
            XCTFail(
                "\(name) returned a structured error: code=\(response.errorCode ?? "?") "
                + "message=\(response.message ?? "?") raw=\(response.rawText)",
                file: file, line: line
            )
        }
        return response
    }

    // MARK: - Parsing

    static func parse(_ result: CallTool.Result) -> ToolResponse {
        let text = Self.firstText(in: result) ?? ""
        return ToolResponse(
            json: Self.decodeJSONObject(from: text),
            isError: result.isError ?? false,
            rawText: text)
    }

    /// Several tools return `"<human prefix>:\n<json>"` (e.g. accessibility_tree
    /// → "Accessibility tree:\n{…}", list_displays → "Connected displays …:\n[…]")
    /// while others return a pure plain-text confirmation with no JSON at all
    /// ("Clicked at (x, y) …"). Try a strict parse first, then fall back to the
    /// substring starting at the first `{`/`[`. Pure plain-text responses yield
    /// an empty object (callers that need them assert on `rawText`).
    private static func decodeJSONObject(from text: String) -> [String: Any] {
        if let data = text.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj
        }
        guard let braceIndex = text.firstIndex(where: { $0 == "{" || $0 == "[" }) else {
            return [:]
        }
        let slice = String(text[braceIndex...])
        if let data = slice.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj
        }
        return [:]
    }

    private static func firstText(in result: CallTool.Result) -> String? {
        for content in result.content {
            if case .text(let text, _, _) = content { return text }
        }
        return nil
    }
}

// MARK: - Value construction sugar (local to the integration target)

extension Value {
    static func num(_ d: Double) -> Value { .double(d) }
}

/// Builds a `[String: Value]` argument map without the `.string(...)` noise.
func args(_ pairs: [String: Value]) -> [String: Value] { pairs }
