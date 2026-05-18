import Foundation
import AppKit
import MCP

/// STORY-009 — exposes `wait_for_element_state` as an MCP tool. Builds a fresh
/// `AXElementStateProbe` per call (the resolver/tree-builder are cheap value
/// wrappers); the poll loop and parser are stateless.
public enum WaitForElementStateModule: ToolModule {

    /// Server-config override for the fixed poll cadence (Q1). Falls back to
    /// 100 ms when unset or unparseable.
    private static var pollIntervalMs: Int {
        if let raw = ProcessInfo.processInfo.environment["MCP_MACOS_CONTROL_POLL_INTERVAL_MS"],
           let parsed = Int(raw), parsed > 0 {
            return parsed
        }
        return WaitForElementStateTool.defaultPollIntervalMs
    }

    public static var tools: [Tool] {
        [
            Tool(
                name: "wait_for_element_state",
                description: "Poll the macOS Accessibility tree until an element matches a state condition — the documented fallback to wait_for_ui_event for transitions that have no AXObserver notification (a button becoming enabled, a spinner disappearing, a row becoming selected). Condition syntax: \"<field> = <value>\". Boolean fields: enabled, exists, focused, selected, expanded, visible_in_viewport, is_main, is_minimized, is_frontmost (e.g. \"enabled = true\", \"exists = false\"). String field: value (exact, case-sensitive, quoted — e.g. value = 'Connected'). Only the = operator is supported at v1. exists is the deliberate way to wait for appearance/disappearance; a not-yet-present element waits the full timeout rather than failing. Optional element_locator (role / title / identifier / label / description) — same shape as click_element. Fixed 100ms poll cadence (server-config override MCP_MACOS_CONTROL_POLL_INTERVAL_MS). Default timeout 30s, hard cap 120s — lower than wait_for_ui_event's 300s because polling has steady cost; for long waits prefer the event-driven tool. Returns the matched element shape (schema_version 3), condition_met, elapsed_seconds, polls_performed. READ-ONLY and idempotent in intent (re-running with the same condition converges on the same observed state). Structured errors per STORY-016: state_condition_not_met, invalid_condition_expression, timeout_exceeds_maximum, accessibility_permission_required, application_not_found, invalid_input.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "condition": [
                            "type": "string",
                            "description": "State predicate \"<field> = <value>\". Fields: enabled, exists, focused, selected, expanded, visible_in_viewport, is_main, is_minimized, is_frontmost (boolean — true/false); value (quoted string, exact case-sensitive match). Operator: = only."
                        ],
                        "state": [
                            "type": "string",
                            "description": "Deprecated alias for 'condition' (accepted for one minor version). 'condition' wins if both are supplied."
                        ],
                        "application": [
                            "type": "string",
                            "description": "Target application — bundle id (e.g. com.apple.TextEdit) or localized name (e.g. TextEdit)."
                        ],
                        "element_locator": [
                            "type": "object",
                            "description": "Optional element to poll. role / title / identifier / label / description — the same locator shape as click_element. May also be supplied as inline top-level fields.",
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
                            "description": "Maximum wait in seconds. Defaults to 30. Hard-capped at 120 — longer requests return timeout_exceeds_maximum; use wait_for_ui_event for long event-driven waits.",
                            "default": 30,
                            "minimum": 0,
                            "maximum": 120
                        ]
                    ],
                    required: ["condition", "application"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true,
                    openWorldHint: true
                )
            )
        ]
    }

    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        guard params.name == "wait_for_element_state" else { return nil }

        let bridge = AXApplicationBridgeImpl()
        let resolver = AXElementResolver(bridge: bridge)
        let treeBuilder = AccessibilityTreeBuilder(bridge: bridge)

        let tool = WaitForElementStateTool(
            probeFactory: { locator, pid, needsViewport in
                AXElementStateProbe(
                    resolver: resolver,
                    treeBuilder: treeBuilder,
                    locator: locator,
                    pid: pid,
                    needsViewport: needsViewport
                )
            },
            clock: SystemClock(),
            pollIntervalMs: pollIntervalMs
        )
        return await tool.execute(params)
    }
}
