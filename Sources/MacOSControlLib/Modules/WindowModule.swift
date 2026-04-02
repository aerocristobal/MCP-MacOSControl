import Foundation
import MCP

public enum WindowModule: ToolModule {
    public static var tools: [Tool] {
        [
            Tool(
                name: "list_windows",
                description: "List all open windows on the system",
                inputSchema: jsonSchema(type: "object")
            ),
            Tool(
                name: "activate_window",
                description: "Activate a window (bring it to the foreground) by matching its title",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "title_pattern": ["type": "string", "description": "Window title pattern"],
                        "use_regex": ["type": "boolean", "description": "Use regex for pattern matching", "default": false],
                        "threshold": ["type": "integer", "description": "Fuzzy match threshold (0-100)", "default": 60]
                    ],
                    required: ["title_pattern"]
                )
            ),
        ]
    }

    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]
        switch params.name {
        case "list_windows":
            do {
                let windows = try WindowManagement.listWindows()
                let jsonData = try JSONSerialization.data(withJSONObject: windows)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(
                    content: [.text("Found \(windows.count) windows\n\(jsonString)")],
                    isError: false
                )
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "activate_window":
            guard let titlePattern = args["title_pattern"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: title_pattern required")], isError: true)
            }
            let useRegex = args["use_regex"]?.boolValue ?? false
            let threshold = args["threshold"]?.intValue ?? 60
            do {
                try WindowManagement.activateWindow(titlePattern: titlePattern, useRegex: useRegex, threshold: threshold)
                return .init(content: [.text("Activated window: \(titlePattern)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        default:
            return nil
        }
    }
}
