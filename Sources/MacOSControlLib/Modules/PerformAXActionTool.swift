import Foundation
import MCP

/// The eight standard `AXUIElementPerformAction` action names. App-defined custom
/// actions (e.g. `AXShowAlternateUI`) are dispatched only when the caller passes
/// `allow_custom: true` — a small but real safety boundary against typos and
/// accidental dispatch of unfamiliar actions.
private let STANDARD_AX_ACTIONS: Set<String> = [
    "AXPress",
    "AXIncrement",
    "AXDecrement",
    "AXConfirm",
    "AXCancel",
    "AXShowMenu",
    "AXRaise",
    "AXPick"
]

public final class PerformAXActionTool {
    private let resolver: AXElementResolving
    private let interactor: AXElementInteracting
    private let enumerator: AXActionEnumerating
    private let bridge: AXApplicationBridge

    public init(
        resolver: AXElementResolving,
        interactor: AXElementInteracting,
        enumerator: AXActionEnumerating,
        bridge: AXApplicationBridge
    ) {
        self.resolver = resolver
        self.interactor = interactor
        self.enumerator = enumerator
        self.bridge = bridge
    }

    public func execute(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]

        let role = args["role"]?.stringValue
        let title = args["title"]?.stringValue
        let identifier = args["identifier"]?.stringValue
        let label = args["label"]?.stringValue
        let description = args["description"]?.stringValue
        let application = args["application"]?.stringValue
        let action = args["action"]?.stringValue
        let allowCustom = args["allow_custom"]?.boolValue ?? false

        guard role != nil || title != nil || identifier != nil || label != nil || description != nil else {
            return errorResult(
                code: "invalid_input",
                message: "perform_ax_action requires at least one locator (role, title, identifier, label, or description)"
            )
        }

        let scope = scope(for: application)

        let resolved: AXElementReference
        do {
            resolved = try resolveElement(
                role: role,
                title: title,
                identifier: identifier,
                label: label,
                description: description,
                scope: scope
            )
        } catch let notFound as AXNotFoundError {
            return errorResult(code: "element_not_found", message: notFound.searchCriteria)
        } catch let resolution as AXResolutionError {
            return resolution.toStructuredResult()
        } catch {
            return errorResult(code: "element_not_found", message: error.localizedDescription)
        }

        // Discovery path: action omitted → return supported list, no dispatch.
        guard let action = action, !action.isEmpty else {
            return discoveryResult(for: resolved)
        }

        // Whitelist gate: reject typo-prone unknown action strings unless the caller
        // explicitly opts in. This avoids late silent no-ops at the AX layer.
        if !STANDARD_AX_ACTIONS.contains(action) && !allowCustom {
            return notSupportedResult(
                action: action,
                supported: Array(STANDARD_AX_ACTIONS).sorted(),
                reason: "action '\(action)' is not in the standard AX action whitelist; pass allow_custom: true to dispatch app-defined actions"
            )
        }

        // Defense in depth: ask the element which actions it actually supports
        // and reject before touching the system if not in the list.
        let supported: [String]
        do {
            supported = try enumerator.actionNames(for: resolved)
        } catch let resolution as AXResolutionError {
            return resolution.toStructuredResult()
        } catch {
            return errorResult(code: "action_failed", message: error.localizedDescription)
        }

        if !supported.contains(action) {
            return notSupportedResult(action: action, supported: supported, reason: nil)
        }

        do {
            try interactor.perform(action, on: resolved)
        } catch let actionErr as AXActionError {
            return actionErr.toStructuredResult()
        } catch {
            return errorResult(code: "action_failed", message: error.localizedDescription)
        }

        return successResult(for: resolved, action: action)
    }

    // MARK: - Resolution + post-validation (mirrors ClickElementTool precedence)

    private func resolveElement(
        role: String?,
        title: String?,
        identifier: String?,
        label: String?,
        description: String?,
        scope: AXResolverScope?
    ) throws -> AXElementReference {
        let candidate: AXElementReference
        if let id = identifier {
            candidate = try resolver.findElement(by: .identifier, value: id, scope: scope)
        } else if title != nil {
            candidate = try resolver.findElement(role: role, title: title, scope: scope)
        } else if let l = label {
            candidate = try resolver.findElement(by: .label, value: l, scope: scope)
        } else if let d = description {
            candidate = try resolver.findElement(by: .description, value: d, scope: scope)
        } else if let r = role {
            candidate = try resolver.findElement(by: .role, value: r, scope: scope)
        } else {
            throw AXNotFoundError(searchCriteria: "(no locators)")
        }

        try validate(
            candidate,
            role: role,
            title: title,
            label: label,
            description: description
        )
        return candidate
    }

    private func validate(
        _ ref: AXElementReference,
        role: String?,
        title: String?,
        label: String?,
        description: String?
    ) throws {
        if let r = role, ref.role != r {
            throw AXNotFoundError(
                searchCriteria: "post-validation: expected role=\(r), got role=\(ref.role ?? "nil")"
            )
        }
        if let t = title, ref.title != t {
            throw AXNotFoundError(
                searchCriteria: "post-validation: expected title=\(t), got title=\(ref.title ?? "nil")"
            )
        }
        if let l = label, ref.label != l {
            throw AXNotFoundError(
                searchCriteria: "post-validation: expected label=\(l), got label=\(ref.label ?? "nil")"
            )
        }
        if let d = description, ref.description != d {
            throw AXNotFoundError(
                searchCriteria: "post-validation: expected description=\(d), got description=\(ref.description ?? "nil")"
            )
        }
    }

    // MARK: - Result builders

    private func scope(for application: String?) -> AXResolverScope? {
        guard let application = application, !application.isEmpty else { return nil }
        return application.contains(".")
            ? .bundleId(application)
            : .name(application)
    }

    private func discoveryResult(for ref: AXElementReference) -> CallTool.Result {
        let supported: [String]
        do {
            supported = try enumerator.actionNames(for: ref)
        } catch let resolution as AXResolutionError {
            return resolution.toStructuredResult()
        } catch {
            return errorResult(code: "action_failed", message: error.localizedDescription)
        }
        let payload: [String: Any] = [
            "ok": true,
            "mode": "discovery",
            "identifier": ref.identifier ?? NSNull(),
            "role": ref.role ?? NSNull(),
            "title": ref.title ?? NSNull(),
            "supported_actions": supported
        ]
        let text = jsonString(payload) ?? "{\"ok\":true,\"supported_actions\":[]}"
        return .init(content: [.text(text)], isError: false)
    }

    private func successResult(for ref: AXElementReference, action: String) -> CallTool.Result {
        let payload: [String: Any] = [
            "ok": true,
            "action": action,
            "identifier": ref.identifier ?? NSNull(),
            "role": ref.role ?? NSNull(),
            "title": ref.title ?? NSNull()
        ]
        let text = jsonString(payload) ?? "{\"ok\":true}"
        return .init(content: [.text(text)], isError: false)
    }

    private func notSupportedResult(
        action: String,
        supported: [String],
        reason: String?
    ) -> CallTool.Result {
        var details: [String: Any] = [
            "action": action,
            "supported_actions": supported
        ]
        if let reason = reason { details["reason"] = reason }
        return MCPErrorResponseBuilder.shared.build(
            code: "action_not_supported",
            message: reason ?? "action '\(action)' is not in the element's supported_actions list",
            details: details
        )
    }

    private func errorResult(code: String, message: String) -> CallTool.Result {
        MCPErrorResponseBuilder.shared.build(code: code, message: message)
    }

    private func jsonString(_ payload: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
