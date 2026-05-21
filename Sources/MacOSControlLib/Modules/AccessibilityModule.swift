import Foundation
import AppKit
import MCP

public enum AccessibilityModule: ToolModule {
    public static var tools: [Tool] {
        [
            Tool(
                name: "accessibility_tree",
                description: "Read the accessibility tree of a macOS application (AXUIElement). Each node includes role, title, description, value, position, size, identifier, actions (per-node AXAction names), enabled, settable (whether AXValue is writable), focused (keyboard focus), selected (for rows / cells / tabs / menu items), expanded (disclosure / popup state), visible_in_viewport (any pixel intersection with containing window), and truncated (set on parents whose children were pruned by max_depth — re-request with a higher max_depth to drill in). AXWindow nodes additionally include is_main, is_minimized, and is_frontmost. Top-level schema_version is 3. Default max_depth is 6 — sufficient for toolbars / dialogs / menubar; pass 3 for smaller responses or 12+ for deeply nested apps. For ambient context (knowing which app is frontmost across turns), subscribe to the MCP Resource macos://ui/active-window-tree instead — it shares the same per-node shape and emits notifications/resources/updated on app/window switches. Does NOT work for iPhone Mirroring iOS content — use iphone_screenshot_with_ocr instead.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "app_name": ["type": "string", "description": "Application name (optional, defaults to frontmost app)"],
                        "window_title": ["type": "string", "description": "Window title to target (optional)"],
                        "max_depth": ["type": "integer", "description": "Maximum tree depth (default 6). Root is depth 0; nodes whose pruned children would yield more detail are flagged truncated=true.", "default": 6]
                    ]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "click_element",
                description: "Click a UI element by semantic AX attributes (role, title, identifier, label) instead of pixel coordinates. Resolves the element via the macOS Accessibility tree and dispatches AXPress — works regardless of window position, display scale, or focus. DESTRUCTIVE: may activate Delete / Confirm controls. Returns immediately after AXPress; for post-click state, set return_state=true.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "role": ["type": "string", "description": "AX role to match (e.g., AXButton, AXCheckBox)."],
                        "title": ["type": "string", "description": "AX title to match (e.g., the visible label of a button)."],
                        "identifier": ["type": "string", "description": "AX identifier — most specific locator when available."],
                        "label": ["type": "string", "description": "AX accessibility label."],
                        "description": ["type": "string", "description": "AX description / help text."],
                        "application": ["type": "string", "description": "Restrict the search to this app — bundle ID (e.g., com.apple.TextEdit) or name (e.g., TextEdit)."],
                        "return_state": ["type": "boolean", "description": "If true, re-read the element's value after the press and include it in the response. Defaults to false.", "default": false]
                    ]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: true,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "perform_ax_action",
                description: "Dispatch any standard AX accessibility action (AXPress, AXIncrement, AXShowMenu, AXConfirm, AXCancel, AXDecrement, AXRaise, AXPick) on a UI element resolved by semantic attributes. Use click_element for simple AXPress; use this tool for non-press actions (steppers, popups, confirmations) or to enumerate an element's supported actions. Omit `action` to discover supported actions without dispatching. App-defined custom actions require allow_custom=true. DESTRUCTIVE: can dispatch AXCancel, AXConfirm, and arbitrary custom actions.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "role": ["type": "string", "description": "AX role to match (e.g., AXButton, AXSlider, AXPopUpButton)."],
                        "title": ["type": "string", "description": "AX title to match."],
                        "identifier": ["type": "string", "description": "AX identifier — most specific locator when available."],
                        "label": ["type": "string", "description": "AX accessibility label."],
                        "description": ["type": "string", "description": "AX description / help text."],
                        "application": ["type": "string", "description": "Restrict the search to this app — bundle ID (e.g., com.apple.TextEdit) or name (e.g., TextEdit)."],
                        "action": ["type": "string", "description": "AX action name to dispatch (AXPress, AXIncrement, AXDecrement, AXConfirm, AXCancel, AXShowMenu, AXRaise, AXPick). Omit to return the element's supported_actions list without dispatching."],
                        "allow_custom": ["type": "boolean", "description": "Allow dispatching app-defined actions outside the 8-name standard whitelist (e.g., AXShowAlternateUI). Off by default to catch typos like AXNonsense early.", "default": false]
                    ]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: true,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "find_elements",
                description: "Find UI elements matching a semantic predicate (role / title / identifier / label / description) without retrieving the full accessibility tree. Returns a flat list of matches plus each match's `ax_path` from application root, the same per-node shape as accessibility_tree (schema_version 3 — includes focused / selected / expanded; visible_in_viewport is omitted on these shallow matches by design). Traversal is breadth-first so shallow matches surface first when max_results is hit — payload is bounded by BOTH max_depth (default 12) AND max_results (default 50, max 500). At least one of role / title / title_contains / title_matches / identifier / identifier_matches / label / description MUST be set or the tool returns `predicate_too_broad` before any AX call. At most one title predicate (title / title_contains / title_matches) and at most one identifier predicate (identifier / identifier_matches) per call. Regex compilation errors short-circuit before traversal. Designed to keep tool-call payloads small enough for an agent to reason about within its context window. READ-ONLY.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "application": ["type": "string", "description": "Restrict the search to this app — bundle ID (e.g., com.apple.TextEdit) or name (e.g., TextEdit). Defaults to frontmost app."],
                        "window_title": ["type": "string", "description": "Restrict the search to a window whose title contains this substring (case-insensitive)."],
                        "role": ["type": "string", "description": "AX role to match exactly (e.g., AXButton, AXTextField)."],
                        "title": ["type": "string", "description": "AX title to match exactly. Mutually exclusive with title_contains and title_matches."],
                        "title_contains": ["type": "string", "description": "Case-insensitive substring match against AX title. Mutually exclusive with title and title_matches."],
                        "title_matches": ["type": "string", "description": "ICU regex matched against AX title. Mutually exclusive with title and title_contains. invalid_regex short-circuits before traversal."],
                        "identifier": ["type": "string", "description": "AX identifier to match exactly. Mutually exclusive with identifier_matches."],
                        "identifier_matches": ["type": "string", "description": "ICU regex matched against AX identifier. Mutually exclusive with identifier."],
                        "label": ["type": "string", "description": "AX accessibility label to match exactly."],
                        "description": ["type": "string", "description": "AX description / help text to match exactly."],
                        "max_results": ["type": "integer", "description": "Hard cap on returned matches; clamped to [1, 500]. truncated_results=true if predicate matched additional nodes beyond the cap. Default 50.", "default": 50],
                        "max_depth": ["type": "integer", "description": "Maximum tree depth to traverse. Root is depth 0. Default 12 — deeper than accessibility_tree's 6 since payload is bounded by max_results too.", "default": 12]
                    ]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "element_at_position",
                description: "Resolve the macOS AX element under a screen coordinate. Inverse of click_element: takes (x, y) and returns the element's role, title, description, identifier, position, size, value, focused, selected, expanded, and (for interactive roles) actions / enabled / settable — the same per-node shape as accessibility_tree (schema_version 3). visible_in_viewport is omitted on this shallow result by design (the user already pointed at the element, so it is on-screen). Coordinates are logical points, top-left origin, global across the union of attached displays. On a single 1920×1080 retina display, the bottom-right corner is x=1920, y=1080 (logical points), not 3840/2160 (device pixels). Pass display_index to provide display-local coordinates that the tool will offset into global space. Returns the topmost AXApplication with a `note` field when the coordinate falls on empty desktop background. READ-ONLY: does not click, focus, or otherwise modify UI state.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "x": ["type": "number", "description": "X coordinate (logical points). Global across all displays unless display_index is also provided, in which case x is display-local."],
                        "y": ["type": "number", "description": "Y coordinate (logical points). Top-left origin. Global across all displays unless display_index is also provided."],
                        "display_index": ["type": "integer", "description": "Optional. Index into the active display list (0 = main display). When provided, (x, y) is interpreted as display-local and offset into global by adding the display's frame origin."]
                    ],
                    required: ["x", "y"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            )
        ]
    }

    public static func handle(_ params: CallTool.Parameters, context: ToolCallContext) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]
        switch params.name {
        case "accessibility_tree":
            let appName = args["app_name"]?.stringValue
            let windowTitle = args["window_title"]?.stringValue
            let maxDepth = args["max_depth"]?.intValue ?? 6

            do {
                guard AXIsProcessTrusted() else {
                    throw MCPError.accessibilityPermissionRequired
                }

                let runningApps = NSWorkspace.shared.runningApplications
                let targetApp: NSRunningApplication?
                if let appName {
                    targetApp = runningApps.first { $0.localizedName?.localizedCaseInsensitiveContains(appName) == true }
                } else {
                    targetApp = NSWorkspace.shared.frontmostApplication
                }
                guard let app = targetApp else {
                    throw MCPError.windowNotFound("Application '\(appName ?? "frontmost")' not found")
                }

                let bridge = AXApplicationBridgeImpl()
                let builder = AccessibilityTreeBuilder(bridge: bridge)
                let serializer = AXNodeSerializer()

                let root = try builder.build(forPID: app.processIdentifier, windowTitle: windowTitle, maxDepth: maxDepth)
                let response = serializer.serializeRoot(root)

                let jsonData = try JSONSerialization.data(withJSONObject: response, options: [.prettyPrinted, .sortedKeys])
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                return .init(content: [.text("Accessibility tree:\n\(jsonString)")], isError: false)
            } catch let error as MCPError {
                return error.toStructuredResult()
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "click_element":
            let bridge = AXApplicationBridgeImpl()
            let resolver = AXElementResolver(bridge: bridge)
            let interactor = AXElementInteractor(bridge: bridge)
            let tool = ClickElementTool(
                resolver: resolver,
                interactor: interactor,
                bridge: bridge
            )
            return try await tool.execute(params)

        case "perform_ax_action":
            let bridge = AXApplicationBridgeImpl()
            let resolver = AXElementResolver(bridge: bridge)
            let interactor = AXElementInteractor(bridge: bridge)
            let enumerator = AXActionEnumerator(bridge: bridge)
            let tool = PerformAXActionTool(
                resolver: resolver,
                interactor: interactor,
                enumerator: enumerator,
                bridge: bridge
            )
            return try await tool.execute(params)

        case "find_elements":
            let bridge = AXApplicationBridgeImpl()
            let tool = FindElementsTool(bridge: bridge)
            return try await tool.execute(params)

        case "element_at_position":
            let bridge = AXApplicationBridgeImpl()
            let displays = ActiveDisplayEnumerator().enumerate()
            let translator = DisplayCoordinateTranslator(displays: displays)
            let validator = DisplayBoundsValidator(displays: displays)
            let treeBuilder = AccessibilityTreeBuilder(bridge: bridge)
            let tool = ElementAtPositionTool(
                bridge: bridge,
                translator: translator,
                validator: validator,
                treeBuilder: treeBuilder
            )
            return try await tool.execute(params)

        default:
            return nil
        }
    }
}
