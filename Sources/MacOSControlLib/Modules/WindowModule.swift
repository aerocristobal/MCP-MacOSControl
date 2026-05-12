import Foundation
import MCP

public enum WindowModule: ToolModule {
    public static var tools: [Tool] {
        [
            Tool(
                name: "list_windows",
                description: "Enumerate every on-screen window across all applications, with title, owner PID, window ID, and frame bounds. Use to discover which app currently owns a target window before activating or capturing it. Read-only; returns a JSON array.",
                inputSchema: jsonSchema(type: "object"),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "activate_window",
                description: "Raise and focus a window whose title matches the given pattern. Use to ensure subsequent keyboard / click events land in the intended window. Idempotent — focusing an already-frontmost window is a no-op. Returns a confirmation string naming the activated window.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "title_pattern": ["type": "string", "description": "Window title pattern to match. Fuzzy substring by default; regex when use_regex=true."],
                        "use_regex": ["type": "boolean", "description": "Match title_pattern as a regex. Defaults to false.", "default": false],
                        "threshold": ["type": "integer", "description": "Fuzzy match threshold (0-100) used when use_regex=false. Defaults to 60.", "default": 60]
                    ],
                    required: ["title_pattern"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: false,
                    idempotentHint: true
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
