import Foundation
import MCP

public final class ClickElementTool {
    private let resolver: AXElementResolving
    private let interactor: AXElementInteracting
    private let bridge: AXApplicationBridge

    public init(
        resolver: AXElementResolving,
        interactor: AXElementInteracting,
        bridge: AXApplicationBridge
    ) {
        self.resolver = resolver
        self.interactor = interactor
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
        let returnState = args["return_state"]?.boolValue ?? false

        guard role != nil || title != nil || identifier != nil || label != nil || description != nil else {
            return errorResult(
                code: "invalid_input",
                message: "click_element requires at least one locator (role, title, identifier, label, or description)"
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
            return errorResult(
                code: "element_not_found",
                message: notFound.searchCriteria
            )
        } catch let resolution as AXResolutionError {
            return resolution.toStructuredResult()
        } catch {
            return errorResult(
                code: "element_not_found",
                message: error.localizedDescription
            )
        }

        do {
            try interactor.performPress(resolved)
        } catch let action as AXActionError {
            return action.toStructuredResult()
        } catch {
            return errorResult(
                code: "action_failed",
                message: error.localizedDescription
            )
        }

        return successResult(for: resolved, returnState: returnState)
    }

    // MARK: - Resolution + post-validation

    private func resolveElement(
        role: String?,
        title: String?,
        identifier: String?,
        label: String?,
        description: String?,
        scope: AXResolverScope?
    ) throws -> AXElementReference {
        // Precedence: identifier > title (with optional role) > label > description > role-only.
        // Each step dispatches to the most specific resolver call available; remaining
        // locators are checked post-resolution as an AND-filter.
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

    // MARK: - Helpers

    private func scope(for application: String?) -> AXResolverScope? {
        guard let application = application, !application.isEmpty else { return nil }
        return application.contains(".")
            ? .bundleId(application)
            : .name(application)
    }

    private func successResult(for ref: AXElementReference, returnState: Bool) -> CallTool.Result {
        var payload: [String: Any] = [
            "ok": true,
            "identifier": ref.identifier ?? NSNull(),
            "role": ref.role ?? NSNull(),
            "title": ref.title ?? NSNull()
        ]
        if returnState, let value = bridge.value(of: ref) {
            payload["value"] = value
        }
        let text = jsonString(payload) ?? "{\"ok\":true}"
        return .init(content: [.text(text)], isError: false)
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
