import Foundation
import AppKit
import MCP

public enum SystemModule: ToolModule {
    public static var tools: [Tool] {
        [
            Tool(
                name: "check_permissions",
                description: "Check system permissions required for MCP server functionality",
                inputSchema: jsonSchema(type: "object")
            ),
            Tool(
                name: "wait_milliseconds",
                description: "Wait for a specified number of milliseconds",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "milliseconds": ["type": "integer", "description": "Milliseconds to wait"]
                    ],
                    required: ["milliseconds"]
                )
            ),
        ]
    }

    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]
        switch params.name {
        case "check_permissions":
            var permissionStatus: [String: Any] = [:]

            let screenRecordingGranted = ScreenCapture.checkScreenRecordingPermission()
            permissionStatus["screen_recording"] = [
                "granted": screenRecordingGranted,
                "required_for": ["take_screenshot", "take_screenshot_with_ocr", "analyze_screen_now", "start_screen_monitoring", "continuous capture tools"],
                "instructions": screenRecordingGranted ? "Permission granted" : "Go to System Settings > Privacy & Security > Screen Recording and enable permission for the app running this MCP server (e.g., Claude Desktop)"
            ]

            let accessibilityGranted = AXIsProcessTrusted()
            permissionStatus["accessibility"] = [
                "granted": accessibilityGranted,
                "required_for": ["click_screen", "move_mouse", "type_text", "press_keys", "drag_mouse", "all mouse and keyboard control tools"],
                "instructions": accessibilityGranted ? "Permission granted" : "Go to System Settings > Privacy & Security > Accessibility and enable permission for the app running this MCP server (e.g., Claude Desktop)"
            ]

            let allGranted = screenRecordingGranted && accessibilityGranted
            permissionStatus["overall_status"] = allGranted ? "All permissions granted" : "Some permissions missing - see details above"

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: permissionStatus)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                return .init(
                    content: [.text("Permission Status:\n\(jsonString)")],
                    isError: !allGranted
                )
            } catch {
                return .init(content: [.text("Error checking permissions: \(error.localizedDescription)")], isError: true)
            }

        case "wait_milliseconds":
            guard let milliseconds = args["milliseconds"]?.intValue else {
                return .init(content: [.text("Invalid parameters: milliseconds required")], isError: true)
            }
            let nanoseconds = UInt64(milliseconds) * 1_000_000
            try await Task.sleep(nanoseconds: nanoseconds)
            return .init(content: [.text("Waited \(milliseconds)ms")], isError: false)

        default:
            return nil
        }
    }
}
