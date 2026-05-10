import Foundation
import AppKit
import MCP

public final class ClickMenuItemTool {

    public static let maxPathDepth = 6

    private let backend: MenuClickBackend
    private let normalizer: MenuItemNormalizer

    public init(backend: MenuClickBackend, normalizer: MenuItemNormalizer) {
        self.backend = backend
        self.normalizer = normalizer
    }

    public func execute(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]

        // path — required array of strings, length 1...maxPathDepth (after
        // normalization, each component must be non-empty).
        guard let pathValue = args["path"], case .array(let rawPath) = pathValue else {
            return errorResult(code: "invalid_input",
                               message: "click_menu_item requires a non-empty 'path' array of strings")
        }

        var pathStrings: [String] = []
        for entry in rawPath {
            guard case .string(let s) = entry else {
                return errorResult(code: "invalid_input",
                                   message: "click_menu_item path elements must be strings")
            }
            pathStrings.append(s)
        }

        if pathStrings.isEmpty {
            return errorResult(code: "invalid_input",
                               message: "click_menu_item path must contain at least 1 element")
        }
        if pathStrings.count > Self.maxPathDepth {
            return errorResult(code: "invalid_input",
                               message: "click_menu_item path depth must not exceed \(Self.maxPathDepth) levels")
        }

        let normalized = pathStrings.map { normalizer.normalize($0) }
        if normalized.contains(where: { $0.isEmpty }) {
            return errorResult(code: "invalid_input",
                               message: "click_menu_item path components must not be empty after normalization")
        }

        // application — optional; falls back to frontmost app's localized name.
        let application: String
        if let provided = args["application"]?.stringValue, !provided.isEmpty {
            application = provided
        } else if let frontmost = NSWorkspace.shared.frontmostApplication?.localizedName,
                  !frontmost.isEmpty {
            application = frontmost
        } else {
            return errorResult(code: "invalid_input",
                               message: "click_menu_item could not determine target application — pass 'application' explicitly")
        }

        let doNotActivate = args["do_not_activate"]?.boolValue ?? false

        // Phase 1: click attempt.
        let clickResult: ClickResult
        do {
            clickResult = try await backend.click(path: normalized,
                                                  application: application,
                                                  doNotActivate: doNotActivate)
        } catch let backendError as MenuClickError {
            switch backendError {
            case .timeout(let after):
                return errorResult(code: "execution_timeout",
                                   message: "menu click exceeded the \(Int(after))-second timeout and was terminated")
            case .backendFailure(let detail):
                return errorResult(code: "backend_error",
                                   message: "menu click backend failure: \(detail)")
            }
        } catch {
            return errorResult(code: "backend_error",
                               message: "menu click failed: \(error.localizedDescription)")
        }

        switch clickResult {
        case .success:
            return successResult(application: application, path: normalized)

        case .disabled:
            return errorResult(
                code: "menu_item_disabled",
                message: "menu item \"\(normalized.last ?? "")\" is currently disabled in \(application)"
            )

        case .notFound:
            // Phase 2: enumerate alternatives at the failing level. Best-effort —
            // if alternatives lookup itself errors, fall back to an empty list.
            let alternatives = (try? await backend.alternatives(forFailingPath: normalized,
                                                                application: application)) ?? []
            return notFoundErrorResult(application: application,
                                       path: normalized,
                                       alternatives: alternatives)
        }
    }

    // MARK: - Result helpers

    private func successResult(application: String, path: [String]) -> CallTool.Result {
        let payload: [String: Any] = [
            "ok": true,
            "application": application,
            "path": path
        ]
        let text = jsonString(payload) ?? "{\"ok\":true}"
        return .init(content: [.text(text)], isError: false)
    }

    private func errorResult(code: String, message: String) -> CallTool.Result {
        let payload: [String: Any] = [
            "ok": false,
            "error": [
                "code": code,
                "message": message
            ]
        ]
        let text = jsonString(payload) ?? "\(code): \(message)"
        return .init(content: [.text(text)], isError: true)
    }

    private func notFoundErrorResult(application: String,
                                     path: [String],
                                     alternatives: [String]) -> CallTool.Result {
        let leaf = path.last ?? ""
        let parentLabel = path.count >= 2 ? path[path.count - 2] : "menu bar"
        let message = "menu item \"\(leaf)\" was not found under \"\(parentLabel)\" in \(application)"

        let payload: [String: Any] = [
            "ok": false,
            "error": [
                "code": "menu_item_not_found",
                "message": message,
                "alternatives": alternatives
            ]
        ]
        let text = jsonString(payload) ?? "menu_item_not_found: \(message)"
        return .init(content: [.text(text)], isError: true)
    }

    private func jsonString(_ payload: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
