import Foundation
import MCP

public enum AccessibilityModule: ToolModule {
    public static var tools: [Tool] {
        [
            Tool(
                name: "accessibility_tree",
                description: "Read the accessibility tree of a macOS application window (AXUIElement). Does NOT work for iPhone Mirroring iOS content — use iphone_screenshot_with_ocr instead.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "app_name": ["type": "string", "description": "Application name (optional, defaults to frontmost app)"],
                        "window_title": ["type": "string", "description": "Window title to target (optional)"],
                        "max_depth": ["type": "integer", "description": "Maximum tree depth", "default": 3]
                    ]
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
                        "return_state": ["type": "boolean", "description": "If true, re-read the element's value after the press and include it in the response.", "default": false]
                    ]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: true
                )
            )
        ]
    }

    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]
        switch params.name {
        case "accessibility_tree":
            let appName = args["app_name"]?.stringValue
            let windowTitle = args["window_title"]?.stringValue
            let maxDepth = args["max_depth"]?.intValue ?? 3

            do {
                let tree = try AccessibilityTreeReader.readTree(
                    appName: appName,
                    windowTitle: windowTitle,
                    maxDepth: maxDepth
                )
                let jsonData = try JSONSerialization.data(withJSONObject: tree, options: [.prettyPrinted, .sortedKeys])
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                return .init(content: [.text("Accessibility tree:\n\(jsonString)")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
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

        default:
            return nil
        }
    }
}
