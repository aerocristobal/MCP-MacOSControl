import Foundation
import AppKit
import MCP

/// STORY-018 — exposes `wait_for_app_event` as an MCP tool. Owns construction
/// of the (shared, process-lifetime) `NSWorkspaceEventBridge` so multiplexing
/// across concurrent calls happens at module scope, not per-call.
public enum WaitForAppEventModule: ToolModule {

    /// Process-lifetime bridge. Long-lived intentionally — the multiplexing
    /// invariant ("one NSWorkspace observer per (event, bundle_id) across all
    /// callers") relies on every `wait_for_app_event` call routing through the
    /// same actor instance. Deliberately separate from STORY-013's
    /// frontmost-app resource observer (Story Q4).
    private static let sharedManager = NSWorkspaceEventBridge(
        notificationCenter: NSWorkspaceNotificationCenter()
    )

    public static var tools: [Tool] {
        [
            Tool(
                name: "wait_for_app_event",
                description: "Subscribe to a macOS application-lifecycle event (NSWorkspace notification) and block until it fires — the event-driven replacement for sleep / get_running_apps polling when sequencing \"open app → app is ready → interact\" workflows. Unlike wait_for_ui_event (AXObserver, requires an already-running AX-queryable target), this works before the app exists and needs no accessibility permission. Supported events: launched, activated, terminated, deactivated, hidden, unhidden. Optional bundle_identifier filters to one app (reverse-DNS, e.g. com.apple.TextEdit); omit it to resolve on the next matching event from any application. Resolves only on the next transition, never the current state (use list_windows / accessibility_tree to check current state first). Multiple concurrent calls on the same (event, bundle_identifier) share one underlying observer. Default timeout 30s, hard cap 300s. Returns { event_type, bundle_identifier, pid, localized_name, interaction_method: \"nsworkspace_observer\", elapsed_seconds }. READ-ONLY: never mutates state; non-idempotent because the outcome depends on time-varying lifecycle events. Structured errors per STORY-016: wait_timeout, unsupported_app_event, invalid_bundle_identifier, timeout_exceeds_maximum.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "event": [
                            "type": "string",
                            "description": "Application lifecycle event to wait for. One of: launched, activated, terminated, deactivated, hidden, unhidden.",
                            "enum": AppEventType.supported
                        ],
                        "bundle_identifier": [
                            "type": "string",
                            "description": "Optional reverse-DNS bundle id to filter to (e.g. com.apple.TextEdit). Omit to resolve on the next matching event from any application."
                        ],
                        "timeout_seconds": [
                            "type": "number",
                            "description": "Maximum wait in seconds. Defaults to 30. Hard-capped at 300 — longer requests return timeout_exceeds_maximum.",
                            "default": 30,
                            "minimum": 0,
                            "maximum": 300
                        ]
                    ],
                    required: ["event"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: false,
                    openWorldHint: true
                )
            )
        ]
    }

    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        guard params.name == "wait_for_app_event" else { return nil }
        let tool = WaitForAppEventTool(manager: sharedManager)
        return await tool.execute(params)
    }
}
