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
            Tool(
                name: "wait_for_text",
                description: "Poll screenshot+OCR until specific text appears or timeout",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "text": ["type": "string", "description": "Text to wait for (case-insensitive substring match)"],
                        "timeout_ms": ["type": "integer", "description": "Maximum wait time in milliseconds", "default": 5000],
                        "poll_interval_ms": ["type": "integer", "description": "Time between OCR polls in milliseconds", "default": 500],
                        "title_pattern": ["type": "string", "description": "Optional window title pattern to target"]
                    ],
                    required: ["text"]
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

        case "wait_for_text":
            guard let searchText = args["text"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: text required")], isError: true)
            }
            let timeoutMs = args["timeout_ms"]?.intValue ?? 5000
            let pollIntervalMs = args["poll_interval_ms"]?.intValue ?? 500
            let titlePattern = args["title_pattern"]?.stringValue

            let startTime = DispatchTime.now()
            let timeoutNanos = UInt64(timeoutMs) * 1_000_000
            let pollNanos = UInt64(pollIntervalMs) * 1_000_000

            while true {
                let elapsed = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
                if elapsed >= timeoutNanos {
                    return .init(content: [.text("Timeout: '\(searchText)' not found within \(timeoutMs)ms")], isError: true)
                }

                do {
                    let result = try await OCRProcessor.takeScreenshotWithOCR(
                        titlePattern: titlePattern,
                        useRegex: false,
                        threshold: 60,
                        saveToDownloads: false
                    )

                    // Search OCR results for the target text (case-insensitive)
                    for entry in result.ocrResults {
                        guard entry.count >= 3,
                              let text = entry[1] as? String else { continue }
                        if text.localizedCaseInsensitiveContains(searchText) {
                            let matchInfo: [String: Any] = [
                                "found": true,
                                "text": text,
                                "coordinates": entry[0],
                                "confidence": entry[2],
                                "elapsed_ms": Int(elapsed / 1_000_000)
                            ]
                            let jsonData = try JSONSerialization.data(withJSONObject: matchInfo)
                            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                            return .init(content: [.text("Text found:\n\(jsonString)")], isError: false)
                        }
                    }
                } catch {
                    // OCR failed this poll, continue trying
                }

                try await Task.sleep(nanoseconds: pollNanos)
            }

        default:
            return nil
        }
    }
}
