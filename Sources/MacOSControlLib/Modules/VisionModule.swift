import Foundation
import MCP

public enum VisionModule: ToolModule {
    public static var tools: [Tool] {
        [
            Tool(
                name: "classify_image",
                description: "Run Apple's Vision image-classification model on a base64-encoded image and return the top-K label / confidence pairs. Use when you need a scene-level summary of what is depicted. Read-only and deterministic for a given input. Returns a JSON array of {identifier, confidence} entries.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "image_data": ["type": "string", "description": "Base64-encoded image data (PNG or JPEG)."],
                        "top_k": ["type": "integer", "description": "Number of top classifications to return. Defaults to 5.", "default": 5]
                    ],
                    required: ["image_data"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "detect_objects",
                description: "Detect objects in a base64-encoded image and return their bounding boxes and confidence scores via Vision. Use to locate items in a screenshot or photo. Read-only and deterministic for a given input. Returns a JSON array of {identifier, confidence, bounding_box} entries.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "image_data": ["type": "string", "description": "Base64-encoded image data."],
                        "minimum_confidence": ["type": "number", "description": "Minimum confidence threshold (0.0-1.0). Detections below this are discarded. Defaults to 0.5.", "default": 0.5]
                    ],
                    required: ["image_data"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "detect_rectangles",
                description: "Detect rectangular shapes (cards, documents, buttons, panels) in a base64-encoded image via Vision and return their bounding quadrilaterals. Use to discover UI containers or scannable pages. Read-only and deterministic for a given input. Returns a JSON array of corner-point sets.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "image_data": ["type": "string", "description": "Base64-encoded image data."],
                        "minimum_confidence": ["type": "number", "description": "Minimum confidence threshold (0.0-1.0). Defaults to 0.5.", "default": 0.5]
                    ],
                    required: ["image_data"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "detect_saliency",
                description: "Generate an attention / saliency map for the image using Vision, highlighting which regions a viewer is most likely to focus on. Use to prioritize where to crop or zoom for further analysis. Read-only and deterministic. Returns a JSON description of the saliency response.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "image_data": ["type": "string", "description": "Base64-encoded image data."]
                    ],
                    required: ["image_data"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "detect_faces",
                description: "Detect faces in a base64-encoded image with bounding boxes via Vision. Use to locate people in screenshots or photos. Read-only and deterministic for a given input. Returns a JSON array of bounding-box entries.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "image_data": ["type": "string", "description": "Base64-encoded image data."]
                    ],
                    required: ["image_data"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
        ]
    }

    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]
        switch params.name {
        case "classify_image":
            guard let imageBase64 = args["image_data"]?.stringValue,
                  let imageData = Data(base64Encoded: imageBase64) else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "image_data (base64) required")
            }

            let topK = args["top_k"]?.intValue ?? 5

            do {
                let classifications = try await VisionAnalyzer.classifyImage(imageData: imageData, topK: topK)
                let jsonData = try JSONSerialization.data(withJSONObject: classifications)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Image classifications (top \(topK)):\n\(jsonString)")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "detect_objects":
            guard let imageBase64 = args["image_data"]?.stringValue,
                  let imageData = Data(base64Encoded: imageBase64) else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "image_data (base64) required")
            }

            let minConfidence = Float(args["minimum_confidence"]?.doubleValue ?? 0.5)

            do {
                let objects = try await VisionAnalyzer.detectObjects(imageData: imageData, minimumConfidence: minConfidence)
                let jsonData = try JSONSerialization.data(withJSONObject: objects)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Detected objects (\(objects.count)):\n\(jsonString)")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "detect_rectangles":
            guard let imageBase64 = args["image_data"]?.stringValue,
                  let imageData = Data(base64Encoded: imageBase64) else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "image_data (base64) required")
            }

            let minConfidence = Float(args["minimum_confidence"]?.doubleValue ?? 0.5)

            do {
                let rectangles = try await VisionAnalyzer.detectRectangles(imageData: imageData, minimumConfidence: minConfidence)
                let jsonData = try JSONSerialization.data(withJSONObject: rectangles)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Detected rectangles (\(rectangles.count)):\n\(jsonString)")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "detect_saliency":
            guard let imageBase64 = args["image_data"]?.stringValue,
                  let imageData = Data(base64Encoded: imageBase64) else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "image_data (base64) required")
            }

            do {
                let saliency = try await VisionAnalyzer.detectSaliency(imageData: imageData)
                let jsonData = try JSONSerialization.data(withJSONObject: saliency)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Saliency detection:\n\(jsonString)")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "detect_faces":
            guard let imageBase64 = args["image_data"]?.stringValue,
                  let imageData = Data(base64Encoded: imageBase64) else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "image_data (base64) required")
            }

            do {
                let faces = try await VisionAnalyzer.detectFaces(imageData: imageData)
                let jsonData = try JSONSerialization.data(withJSONObject: faces)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Detected faces (\(faces.count)):\n\(jsonString)")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        default:
            return nil
        }
    }
}
