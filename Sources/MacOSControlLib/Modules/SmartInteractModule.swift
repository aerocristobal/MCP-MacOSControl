import Foundation
import MCP

// STORY-010 — registers `smart_interact`, the recommended entry point for AI
// agents. Owns a process-lifetime capability registry (mirrors
// WaitForAppEventModule's shared-manager pattern). The double-load with
// Server.swift's registry is acceptable: load-once, ~27 entries, no hot reload.
public enum SmartInteractModule: ToolModule {

    /// Built once; `load()` failures fall back to an empty (all-`.unknown`)
    /// registry so the optimistic-fallback path still works — exactly the
    /// STORY-019 decoupling guarantee.
    private static let registry: AppCapabilityRegistry = {
        let registry = AppCapabilityRegistry.standardRegistry()
        do {
            try registry.load()
        } catch {
            MCPLogger.warn("smart_interact: capability registry load failed (\(error)); routing optimistically.")
        }
        return registry
    }()

    private static func makeRouter() -> InteractionRouter {
        let bridge = AXApplicationBridgeImpl()
        let resolver = AXElementResolver(bridge: bridge)
        let interactor = AXElementInteractor(bridge: bridge)
        return InteractionRouter(
            layers: [
                AXSemanticLayer(resolver: resolver, interactor: interactor),
                AppleScriptLayer(executor: AppleScriptExecutor()),
                HitTestLayer(bridge: bridge, interactor: interactor),
                CoordinateLayer(actuator: SystemCoordinateActuator())
            ],
            registry: registry)
    }

    public static var tools: [Tool] {
        [
            Tool(
                name: "smart_interact",
                description: "Recommended entry point for UI interaction. State your intent (click / type) and a target; the router automatically selects and falls through the canonical four interaction layers in order — AX semantic → AppleScript → visual hit-test → raw coordinate — skipping layers the per-app capability registry knows fail for the target app. Inputs: intent (click | type), target_description (string, optional — treated as the element's AX title), application (string, optional — bundle id or name; scopes AX resolution and registry lookup), coordinates ({x, y}, optional — enables the hit-test and coordinate layers), value (string, required when intent=type), skip_layers (array, optional — layer names to bypass, e.g. [\"coordinate_fallback\"]). Always returns a decision_log array documenting every layer attempted/skipped/failed with reasons, plus interaction_method and confidence. On exhaustion returns the structured error all_layers_failed with the decision_log and retry_suggestions. NOTE: the router only knows the action dispatched, not that it had the intended effect — verify after acting with wait_for_ui_event / wait_for_element_state. DESTRUCTIVE: may click any control or overwrite text.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "intent": [
                            "type": "string",
                            "description": "What to do. One of: click, type.",
                            "enum": InteractionIntent.allCases.map(\.rawValue)
                        ],
                        "target_description": [
                            "type": "string",
                            "description": "What to act on — treated as the element's AX title for semantic resolution (e.g. \"Bold\")."
                        ],
                        "application": [
                            "type": "string",
                            "description": "Bundle id (e.g. com.apple.TextEdit) or app name. Scopes AX resolution and selects the capability-registry row."
                        ],
                        "coordinates": [
                            "type": "object",
                            "description": "Optional screen point {x, y} in global logical points. Enables the hit-test and coordinate-fallback layers.",
                            "properties": [
                                "x": ["type": "number"],
                                "y": ["type": "number"]
                            ]
                        ],
                        "value": [
                            "type": "string",
                            "description": "Text to enter. Required when intent=type."
                        ],
                        "skip_layers": [
                            "type": "array",
                            "description": "Optional layer names to bypass for this call (ax_semantic, applescript, ax_hit_test, coordinate_fallback).",
                            "items": ["type": "string"]
                        ]
                    ],
                    required: ["intent"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: true,
                    idempotentHint: false,
                    openWorldHint: true
                )
            )
        ]
    }

    public static func handle(_ params: CallTool.Parameters, context: ToolCallContext) async throws -> CallTool.Result? {
        guard params.name == "smart_interact" else { return nil }
        let tool = SmartInteractTool(router: makeRouter())
        return await tool.execute(params)
    }
}
