import Foundation
import MCP

/// STORY-018 — `wait_for_app_event` MCP tool. Subscribes to an NSWorkspace
/// application-lifecycle notification and resumes when it fires or the timeout
/// elapses. Unlike STORY-008's `wait_for_ui_event`, NSWorkspace notifications
/// require no accessibility permission, so there is no permission gate.
public final class WaitForAppEventTool {

    public static let defaultTimeoutSeconds: TimeInterval = 30
    public static let maxTimeoutSeconds: TimeInterval = 300

    private let manager: NSWorkspaceEventManaging

    public init(manager: NSWorkspaceEventManaging) {
        self.manager = manager
    }

    public func execute(_ params: CallTool.Parameters, context: ToolCallContext = .nonCancellable()) async -> CallTool.Result {
        let args = params.arguments ?? [:]

        // --- Input validation -------------------------------------------------
        guard let eventName = args["event"]?.stringValue, !eventName.isEmpty else {
            return MCPErrorResponseBuilder.shared.build(
                code: "invalid_input",
                message: "wait_for_app_event requires 'event'"
            )
        }

        // Unknown event short-circuits first so the agent gets the canonical
        // supported list as quickly as possible.
        guard let event = AppEventType(rawValue: eventName) else {
            return UnsupportedAppEventError(event: eventName).toStructuredResult()
        }

        // Optional bundle_identifier filter — reject malformed values before
        // subscribing so a typo fails fast instead of timing out (Q6).
        var bundleIdentifierFilter: String?
        if let raw = args["bundle_identifier"]?.stringValue, !raw.isEmpty {
            do {
                try BundleIdentifierValidator.validate(raw)
            } catch let invalid as InvalidBundleIdentifierError {
                return invalid.toStructuredResult()
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }
            bundleIdentifierFilter = raw
        }

        let requestedTimeout = args["timeout_seconds"]?.doubleValue ?? Self.defaultTimeoutSeconds
        guard requestedTimeout <= Self.maxTimeoutSeconds else {
            return TimeoutExceedsMaximumError(
                requested: requestedTimeout,
                maximum: Self.maxTimeoutSeconds
            ).toStructuredResult()
        }
        let timeout = max(0, requestedTimeout)

        // --- Wait -------------------------------------------------------------
        let start = Date()
        do {
            let event = try await manager.wait(
                event: event,
                bundleIdentifierFilter: bundleIdentifierFilter,
                timeout: timeout,
                cancellation: context.cancellation
            )
            let elapsed = Date().timeIntervalSince(start)
            return successResult(event: event, elapsedSeconds: elapsed)
        } catch let timeoutError as AppEventWaitTimeoutError {
            return timeoutError.toStructuredResult()
        } catch is CancellationError {
            return MCPErrorResponseBuilder.shared.build(
                code: "cancelled",
                message: "wait_for_app_event was cancelled."
            )
        } catch {
            return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
        }
    }

    // MARK: - Response

    private func successResult(
        event: AppLifecycleEvent,
        elapsedSeconds: TimeInterval
    ) -> CallTool.Result {
        var payload: [String: Any] = [
            "event_type": event.eventType.rawValue,
            "pid": Int(event.pid),
            "interaction_method": "nsworkspace_observer",
            "elapsed_seconds": elapsedSeconds
        ]
        if let bundleIdentifier = event.bundleIdentifier {
            payload["bundle_identifier"] = bundleIdentifier
        }
        if let localizedName = event.localizedName {
            payload["localized_name"] = localizedName
        }
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
}
