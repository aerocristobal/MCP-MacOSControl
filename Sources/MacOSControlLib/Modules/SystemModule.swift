import Foundation
import AppKit
import MCP

public enum SystemModule: ToolModule {
    public static var tools: [Tool] {
        [
            Tool(
                name: "check_permissions",
                description: "Inspect the macOS permissions this MCP server needs (Screen Recording, Accessibility) and report which are granted. Use as a pre-flight check before invoking input or capture tools. Read-only; returns a JSON object listing each permission, its grant status, the tools that depend on it, and remediation instructions.",
                inputSchema: jsonSchema(type: "object"),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "wait_milliseconds",
                description: "Block for the requested number of milliseconds. Use sparingly — prefer wait_for_text / wait_for_element_state when waiting for a UI condition. Read-only with respect to the system; non-idempotent because elapsed time differs per call. Returns a confirmation string.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "milliseconds": ["type": "integer", "description": "Number of milliseconds to sleep before returning."]
                    ],
                    required: ["milliseconds"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "wait_for_text",
                description: "Poll screen OCR until specific text appears, or fail with timeout. Use to synchronize with UI transitions instead of sleeping. Read-only with respect to the system; non-idempotent because the screen state changes over time. Returns a JSON object describing the matched text and its coordinates.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "text": ["type": "string", "description": "Text to wait for (case-insensitive substring match)."],
                        "timeout_ms": ["type": "integer", "description": "Maximum wait time in milliseconds. Defaults to 5000.", "default": 5000],
                        "poll_interval_ms": ["type": "integer", "description": "Time between OCR polls in milliseconds. Defaults to 500.", "default": 500],
                        "title_pattern": ["type": "string", "description": "Optional window title pattern to restrict the poll to a specific window."]
                    ],
                    required: ["text"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
        ]
    }

    public static func handle(_ params: CallTool.Parameters, context: ToolCallContext) async throws -> CallTool.Result? {
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
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "wait_milliseconds":
            guard let milliseconds = args["milliseconds"]?.intValue else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "milliseconds required")
            }
            let nanoseconds = UInt64(milliseconds) * 1_000_000
            try await Task.sleep(nanoseconds: nanoseconds)
            return .init(content: [.text("Waited \(milliseconds)ms")], isError: false)

        case "wait_for_text":
            guard let searchText = args["text"]?.stringValue else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "text required")
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
                    return MCPErrorResponseBuilder.shared.build(code: "wait_timeout", message: "'\(searchText)' not found within \(timeoutMs)ms")
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
