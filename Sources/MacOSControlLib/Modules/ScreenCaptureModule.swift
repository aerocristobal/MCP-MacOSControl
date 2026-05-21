import Foundation
import MCP

public enum ScreenCaptureModule: ToolModule {
    public static var tools: [Tool] {
        [
            Tool(
                name: "take_screenshot",
                description: "Capture a PNG of the entire screen or a specific window matched by title pattern. Use when you need a visual snapshot to feed Vision / OCR pipelines or to deliver to a model. Read-only — no system state is modified. Returns base64-encoded PNG image content; optionally also saves a copy to ~/Downloads.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "title_pattern": ["type": "string", "description": "Optional window title pattern. When omitted, captures the entire screen."],
                        "use_regex": ["type": "boolean", "description": "Match title_pattern as a regex instead of fuzzy substring. Defaults to false.", "default": false],
                        "threshold": ["type": "integer", "description": "Fuzzy match threshold (0-100) used when use_regex=false. Defaults to 60.", "default": 60],
                        "save_to_downloads": ["type": "boolean", "description": "Also save the PNG to ~/Downloads for later inspection. Defaults to false.", "default": false]
                    ]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "take_screenshot_with_ocr",
                description: "Capture the screen or a window and run Vision OCR over the result. Use to find UI text with coordinates so a later click_screen or wait_for_text call can target it. Returns a JSON array of [polygon, text, confidence] triples sorted by Vision's recognition order. Read-only with respect to the system.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "title_pattern": ["type": "string", "description": "Optional window title pattern. When omitted, captures the entire screen."],
                        "use_regex": ["type": "boolean", "description": "Match title_pattern as a regex instead of fuzzy substring. Defaults to false.", "default": false],
                        "threshold": ["type": "integer", "description": "Fuzzy match threshold (0-100) used when use_regex=false. Defaults to 60.", "default": 60],
                        "save_to_downloads": ["type": "boolean", "description": "Also save the captured PNG to ~/Downloads. Defaults to false.", "default": false]
                    ]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
        ]
    }

    public static func handle(_ params: CallTool.Parameters, context: ToolCallContext) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]
        switch params.name {
        case "take_screenshot":
            let titlePattern = args["title_pattern"]?.stringValue
            let useRegex = args["use_regex"]?.boolValue ?? false
            let threshold = args["threshold"]?.intValue ?? 60
            let saveToDownloads = args["save_to_downloads"]?.boolValue ?? false

            do {
                let result = try await ScreenCapture.takeScreenshot(
                    titlePattern: titlePattern,
                    useRegex: useRegex,
                    threshold: threshold,
                    saveToDownloads: saveToDownloads
                )

                let base64 = result.imageData.base64EncodedString()
                return .init(
                    content: [.image(data: base64, mimeType: "image/png", annotations: nil, _meta: nil)],
                    isError: false
                )
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "take_screenshot_with_ocr":
            let titlePattern = args["title_pattern"]?.stringValue
            let useRegex = args["use_regex"]?.boolValue ?? false
            let threshold = args["threshold"]?.intValue ?? 60
            let saveToDownloads = args["save_to_downloads"]?.boolValue ?? false

            do {
                let result = try await OCRProcessor.takeScreenshotWithOCR(
                    titlePattern: titlePattern,
                    useRegex: useRegex,
                    threshold: threshold,
                    saveToDownloads: saveToDownloads
                )

                let jsonData = try JSONSerialization.data(withJSONObject: result.ocrResults)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(
                    content: [.text("OCR completed: \(result.ocrResults.count) text elements found\n\(jsonString)")],
                    isError: false
                )
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        default:
            return nil
        }
    }
}
