import Foundation
import AppKit
import ApplicationServices
import MCP

/// STORY-008 — exposes `wait_for_ui_event` as an MCP tool. Owns construction
/// of the (shared, process-lifetime) `AXObserverManager` so multiplexing
/// across concurrent calls happens at module scope, not per-call.
public enum WaitForUIEventModule: ToolModule {

    /// Process-lifetime `AXObserverManager`. Long-lived intentionally — the
    /// multiplexing invariant ("one AXObserver per (pid, notification) across
    /// all callers") relies on every `wait_for_ui_event` call routing through
    /// the same actor instance.
    private static let sharedManager: AXObserverManager = AXObserverManager(
        axBridge: AXObserverBridgeImpl(),
        workspace: NSWorkspaceTerminationObserver()
    )

    public static var tools: [Tool] {
        [
            Tool(
                name: "wait_for_ui_event",
                description: "Subscribe to a macOS Accessibility (AXObserver) notification and block until it fires — the precise replacement for sleep / screenshot-polling loops when waiting for a UI transition. Supported notifications: AXWindowCreated, AXUIElementDestroyed, AXFocusedUIElementChanged, AXValueChanged, AXSelectedTextChanged, AXTitleChanged, AXMainWindowChanged, AXFocusedWindowChanged. Multiple concurrent calls on the same (application, notification) pair share a single underlying AXObserver. Optional element_locator (role / title / identifier / label / description) targets a specific element — useful for AXUIElementDestroyed where the element ref is needed at subscription time so its identity can be reported after destruction. Default timeout 30s, hard cap 300s — for longer watches use MCP Resources subscriptions instead. Returns the matched event's element shape (schema_version 3) plus elapsed_seconds. READ-ONLY: never mutates UI state; non-idempotent because the outcome depends on time-varying UI events. Structured errors per STORY-016: wait_timeout, target_application_terminated, accessibility_permission_required, unsupported_notification, element_not_found, timeout_exceeds_maximum, application_not_found.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "notification": [
                            "type": "string",
                            "description": "AX notification name to subscribe to. One of: AXWindowCreated, AXUIElementDestroyed, AXFocusedUIElementChanged, AXValueChanged, AXSelectedTextChanged, AXTitleChanged, AXMainWindowChanged, AXFocusedWindowChanged. See the ax_observer_notifications prompt for when each fires.",
                            "enum": AXObserverNotification.supported
                        ],
                        "application": [
                            "type": "string",
                            "description": "Target application — bundle id (e.g., com.apple.TextEdit) or localized name (e.g., TextEdit)."
                        ],
                        "element_locator": [
                            "type": "object",
                            "description": "Optional element to target. Resolved before subscription so a missing element fails fast with element_not_found instead of timing out. role / title / identifier / label / description are the same locator shape as click_element.",
                            "properties": [
                                "role": ["type": "string"],
                                "title": ["type": "string"],
                                "identifier": ["type": "string"],
                                "label": ["type": "string"],
                                "description": ["type": "string"]
                            ]
                        ],
                        "timeout_seconds": [
                            "type": "number",
                            "description": "Maximum wait in seconds. Defaults to 30. Hard-capped at 300 — longer requests return timeout_exceeds_maximum.",
                            "default": 30,
                            "minimum": 0,
                            "maximum": 300
                        ]
                    ],
                    required: ["notification", "application"]
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

    public static func handle(_ params: CallTool.Parameters, context: ToolCallContext) async throws -> CallTool.Result? {
        guard params.name == "wait_for_ui_event" else { return nil }

        let bridge = AXApplicationBridgeImpl()
        let resolver = AXElementResolver(bridge: bridge)
        let tool = WaitForUIEventTool(
            manager: sharedManager,
            resolver: resolver
        )
        return await tool.execute(params)
    }
}
