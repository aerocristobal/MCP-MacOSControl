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

        default:
            return nil
        }
    }
}
