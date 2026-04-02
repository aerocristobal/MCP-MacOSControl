import Foundation
import MCP

public enum VisionModule: ToolModule {
    public static var tools: [Tool] {
        [
            Tool(
                name: "classify_image",
                description: "Classify objects in an image using Vision framework",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "image_data": ["type": "string", "description": "Base64 encoded image data"],
                        "top_k": ["type": "integer", "description": "Number of top classifications to return (default: 5)", "default": 5]
                    ],
                    required: ["image_data"]
                )
            ),
            Tool(
                name: "detect_objects",
                description: "Detect objects in an image with bounding boxes",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "image_data": ["type": "string", "description": "Base64 encoded image data"],
                        "minimum_confidence": ["type": "number", "description": "Minimum confidence threshold (0.0-1.0, default: 0.5)", "default": 0.5]
                    ],
                    required: ["image_data"]
                )
            ),
            Tool(
                name: "detect_rectangles",
                description: "Detect rectangles in an image (UI elements, documents, etc.)",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "image_data": ["type": "string", "description": "Base64 encoded image data"],
                        "minimum_confidence": ["type": "number", "description": "Minimum confidence threshold (0.0-1.0, default: 0.5)", "default": 0.5]
                    ],
                    required: ["image_data"]
                )
            ),
            Tool(
                name: "detect_saliency",
                description: "Detect attention-grabbing regions in an image",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "image_data": ["type": "string", "description": "Base64 encoded image data"]
                    ],
                    required: ["image_data"]
                )
            ),
            Tool(
                name: "detect_faces",
                description: "Detect faces in an image with bounding boxes",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "image_data": ["type": "string", "description": "Base64 encoded image data"]
                    ],
                    required: ["image_data"]
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
                return .init(content: [.text("Invalid parameters: image_data (base64) required")], isError: true)
            }

            let topK = args["top_k"]?.intValue ?? 5

            do {
                let classifications = try await VisionAnalyzer.classifyImage(imageData: imageData, topK: topK)
                let jsonData = try JSONSerialization.data(withJSONObject: classifications)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Image classifications (top \(topK)):\n\(jsonString)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "detect_objects":
            guard let imageBase64 = args["image_data"]?.stringValue,
                  let imageData = Data(base64Encoded: imageBase64) else {
                return .init(content: [.text("Invalid parameters: image_data (base64) required")], isError: true)
            }

            let minConfidence = Float(args["minimum_confidence"]?.doubleValue ?? 0.5)

            do {
                let objects = try await VisionAnalyzer.detectObjects(imageData: imageData, minimumConfidence: minConfidence)
                let jsonData = try JSONSerialization.data(withJSONObject: objects)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Detected objects (\(objects.count)):\n\(jsonString)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "detect_rectangles":
            guard let imageBase64 = args["image_data"]?.stringValue,
                  let imageData = Data(base64Encoded: imageBase64) else {
                return .init(content: [.text("Invalid parameters: image_data (base64) required")], isError: true)
            }

            let minConfidence = Float(args["minimum_confidence"]?.doubleValue ?? 0.5)

            do {
                let rectangles = try await VisionAnalyzer.detectRectangles(imageData: imageData, minimumConfidence: minConfidence)
                let jsonData = try JSONSerialization.data(withJSONObject: rectangles)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Detected rectangles (\(rectangles.count)):\n\(jsonString)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "detect_saliency":
            guard let imageBase64 = args["image_data"]?.stringValue,
                  let imageData = Data(base64Encoded: imageBase64) else {
                return .init(content: [.text("Invalid parameters: image_data (base64) required")], isError: true)
            }

            do {
                let saliency = try await VisionAnalyzer.detectSaliency(imageData: imageData)
                let jsonData = try JSONSerialization.data(withJSONObject: saliency)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Saliency detection:\n\(jsonString)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "detect_faces":
            guard let imageBase64 = args["image_data"]?.stringValue,
                  let imageData = Data(base64Encoded: imageBase64) else {
                return .init(content: [.text("Invalid parameters: image_data (base64) required")], isError: true)
            }

            do {
                let faces = try await VisionAnalyzer.detectFaces(imageData: imageData)
                let jsonData = try JSONSerialization.data(withJSONObject: faces)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Detected faces (\(faces.count)):\n\(jsonString)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        default:
            return nil
        }
    }
}
