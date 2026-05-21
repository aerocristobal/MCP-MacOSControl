import Foundation
import AppKit
import MCP

/// STORY-008 — `wait_for_ui_event` MCP tool. Subscribes to an `AXObserver`
/// notification for the named application and resumes when it fires, the
/// application terminates, or the timeout elapses.
public final class WaitForUIEventTool {
    public typealias PIDResolver = (_ application: String) -> (pid_t, String?)?

    public static let defaultTimeoutSeconds: TimeInterval = 30
    public static let maxTimeoutSeconds: TimeInterval = 300

    private let manager: AXObserverManaging
    private let resolver: AXElementResolving
    private let pidResolver: PIDResolver

    public init(
        manager: AXObserverManaging,
        resolver: AXElementResolving,
        pidResolver: PIDResolver? = nil
    ) {
        self.manager = manager
        self.resolver = resolver
        self.pidResolver = pidResolver ?? Self.defaultPIDResolver
    }

    public func execute(_ params: CallTool.Parameters, context: ToolCallContext = .nonCancellable()) async -> CallTool.Result {
        let args = params.arguments ?? [:]

        // --- Input validation -------------------------------------------------
        guard let notification = args["notification"]?.stringValue, !notification.isEmpty else {
            return MCPErrorResponseBuilder.shared.build(
                code: "invalid_input",
                message: "wait_for_ui_event requires 'notification'"
            )
        }
        guard let application = args["application"]?.stringValue, !application.isEmpty else {
            return MCPErrorResponseBuilder.shared.build(
                code: "invalid_input",
                message: "wait_for_ui_event requires 'application'"
            )
        }

        // Unknown notification short-circuits BEFORE permission checks so the
        // agent gets the canonical list as quickly as possible.
        guard AXObserverNotification.isSupported(notification) else {
            return UnsupportedNotificationError(notification: notification).toStructuredResult()
        }

        let requestedTimeout = args["timeout_seconds"]?.doubleValue ?? Self.defaultTimeoutSeconds
        guard requestedTimeout <= Self.maxTimeoutSeconds else {
            return TimeoutExceedsMaximumError(
                requested: requestedTimeout,
                maximum: Self.maxTimeoutSeconds
            ).toStructuredResult()
        }
        let timeout = max(0, requestedTimeout)

        // --- Permission gate --------------------------------------------------
        guard await manager.canSubscribe() else {
            return AccessibilityPermissionRequiredError().toStructuredResult()
        }

        // --- Target resolution ------------------------------------------------
        guard let (pid, bundleId) = pidResolver(application) else {
            return MCPErrorResponseBuilder.shared.build(
                code: "application_not_found",
                message: "Application '\(application)' not found"
            )
        }
        _ = bundleId  // reserved for future use; bundle id flows through the termination error path

        // Optional element_locator: resolve the element NOW so a missing
        // locator fails fast with `element_not_found` instead of subscribing
        // and timing out (Q4). We deliberately do NOT re-target the AX
        // subscription to the resolved element — Story Q6 commits to caching
        // attributes at subscription time; the resolved attributes are surfaced
        // through the structured response when the notification fires.
        var locatorRole: String?
        var locatorTitle: String?
        var locatorIdentifier: String?
        if let locator = extractLocator(from: args), locator.hasAny {
            do {
                let resolved = try resolveLocator(locator, pid: pid)
                locatorRole = resolved.role
                locatorTitle = resolved.title
                locatorIdentifier = resolved.identifier
            } catch let notFound as AXNotFoundError {
                return MCPErrorResponseBuilder.shared.build(
                    code: "element_not_found",
                    message: notFound.searchCriteria
                )
            } catch let resolution as AXResolutionError {
                return resolution.toStructuredResult()
            } catch {
                return MCPErrorResponseBuilder.shared.build(
                    code: "element_not_found",
                    message: error.localizedDescription
                )
            }
        }

        // --- Wait -------------------------------------------------------------
        let start = Date()
        do {
            let event = try await manager.wait(
                for: notification,
                in: pid,
                timeout: timeout,
                cancellation: context.cancellation
            )
            let elapsed = Date().timeIntervalSince(start)
            return successResult(
                event: event,
                elapsedSeconds: elapsed,
                cachedRole: locatorRole,
                cachedTitle: locatorTitle,
                cachedIdentifier: locatorIdentifier
            )
        } catch let timeoutError as WaitTimeoutError {
            return timeoutError.toStructuredResult()
        } catch let terminated as TargetApplicationTerminatedError {
            return terminated.toStructuredResult()
        } catch let permission as AccessibilityPermissionRequiredError {
            return permission.toStructuredResult()
        } catch let resolution as AXResolutionError {
            return resolution.toStructuredResult()
        } catch is CancellationError {
            // STORY-027 — the SDK will suppress the response per the
            // notifications/cancelled contract, but we still need to return a
            // structured value (the type signature requires it). The handler
            // also re-throws so withTaskCancellationHandler can propagate.
            return MCPErrorResponseBuilder.shared.build(
                code: "cancelled",
                message: "wait_for_ui_event was cancelled."
            )
        } catch {
            return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
        }
    }

    // MARK: - Locator handling

    private struct Locator {
        var role: String?
        var title: String?
        var identifier: String?
        var label: String?
        var description: String?

        var hasAny: Bool {
            role != nil || title != nil || identifier != nil || label != nil || description != nil
        }
    }

    private func extractLocator(from args: [String: Value]) -> Locator? {
        // Allow either inline locator fields (parallel to click_element) or a
        // nested element_locator object — the BDD scenarios use both shapes.
        if case .object(let nested) = args["element_locator"] ?? .null {
            return Locator(
                role: nested["role"]?.stringValue,
                title: nested["title"]?.stringValue,
                identifier: nested["identifier"]?.stringValue,
                label: nested["label"]?.stringValue,
                description: nested["description"]?.stringValue
            )
        }
        let inline = Locator(
            role: args["role"]?.stringValue,
            title: args["title"]?.stringValue,
            identifier: args["identifier"]?.stringValue,
            label: args["label"]?.stringValue,
            description: args["description"]?.stringValue
        )
        return inline.hasAny ? inline : nil
    }

    private func resolveLocator(_ locator: Locator, pid: pid_t) throws -> AXElementReference {
        let scope: AXResolverScope = .pid(pid)
        if let id = locator.identifier {
            return try resolver.findElement(by: .identifier, value: id, scope: scope)
        }
        if locator.title != nil || locator.role != nil {
            return try resolver.findElement(role: locator.role, title: locator.title, scope: scope)
        }
        if let label = locator.label {
            return try resolver.findElement(by: .label, value: label, scope: scope)
        }
        if let description = locator.description {
            return try resolver.findElement(by: .description, value: description, scope: scope)
        }
        throw AXNotFoundError(searchCriteria: "(no locators)")
    }

    // MARK: - Response

    private func successResult(
        event: WaitForUIEvent,
        elapsedSeconds: TimeInterval,
        cachedRole: String?,
        cachedTitle: String?,
        cachedIdentifier: String?
    ) -> CallTool.Result {
        var element: [String: Any] = [:]
        if let role = event.elementRole ?? cachedRole { element["role"] = role }
        if let title = event.elementTitle ?? cachedTitle { element["title"] = title }
        if let identifier = event.elementIdentifier ?? cachedIdentifier {
            element["identifier"] = identifier
        }

        let payload: [String: Any] = [
            "schema_version": AXNodeSerializer.schemaVersion,
            "notification": event.notification,
            "element": element,
            "interaction_method": "ax_observer",
            "elapsed_seconds": elapsedSeconds
        ]
        let text = jsonString(payload) ?? "{}"
        return .init(content: [.text(text)], isError: false)
    }

    private func jsonString(_ payload: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Default PID resolver

    private static let defaultPIDResolver: PIDResolver = { application in
        let workspace = NSWorkspace.shared
        let isBundleId = application.contains(".")
        for app in workspace.runningApplications {
            if isBundleId, app.bundleIdentifier == application {
                return (app.processIdentifier, app.bundleIdentifier)
            }
            if !isBundleId, app.localizedName?.localizedCaseInsensitiveContains(application) == true {
                return (app.processIdentifier, app.bundleIdentifier)
            }
        }
        return nil
    }
}
