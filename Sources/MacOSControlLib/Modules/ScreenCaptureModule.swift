import Foundation
import MCP

public enum ScreenCaptureModule: ToolModule {
    public static var tools: [Tool] {
        [
            Tool(
                name: "take_screenshot",
                description: "Get screenshot of entire screen or specific window",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "title_pattern": ["type": "string", "description": "Window title pattern (optional)"],
                        "use_regex": ["type": "boolean", "description": "Use regex for pattern matching", "default": false],
                        "threshold": ["type": "integer", "description": "Fuzzy match threshold (0-100)", "default": 60],
                        "save_to_downloads": ["type": "boolean", "description": "Save screenshot to downloads folder", "default": false]
                    ]
                )
            ),
            Tool(
                name: "take_screenshot_with_ocr",
                description: "Take screenshot and extract text with OCR, returns list of [coordinates, text, confidence]",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "title_pattern": ["type": "string", "description": "Window title pattern (optional)"],
                        "use_regex": ["type": "boolean", "description": "Use regex for pattern matching", "default": false],
                        "threshold": ["type": "integer", "description": "Fuzzy match threshold (0-100)", "default": 60],
                        "save_to_downloads": ["type": "boolean", "description": "Save screenshot to downloads folder", "default": false]
                    ]
                )
            ),
        ]
    }

    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
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
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
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
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        default:
            return nil
        }
    }
}
