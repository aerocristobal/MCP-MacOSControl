import Foundation
import MCP

public enum CoreMLModule: ToolModule {
    public static var tools: [Tool] {
        [
            Tool(
                name: "list_coreml_models",
                description: "List available CoreML models on the system",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "directory": ["type": "string", "description": "Optional directory to search for models"]
                    ]
                )
            ),
            Tool(
                name: "load_coreml_model",
                description: "Load a CoreML model into memory for inference",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "name": ["type": "string", "description": "Name to reference the model by"],
                        "path": ["type": "string", "description": "File path to the .mlmodel or .mlmodelc"]
                    ],
                    required: ["name", "path"]
                )
            ),
            Tool(
                name: "unload_coreml_model",
                description: "Unload a CoreML model from memory",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "name": ["type": "string", "description": "Name of the loaded model to unload"]
                    ],
                    required: ["name"]
                )
            ),
            Tool(
                name: "get_model_info",
                description: "Get metadata and info about a loaded CoreML model",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "name": ["type": "string", "description": "Name of the loaded model"]
                    ],
                    required: ["name"]
                )
            ),
            Tool(
                name: "generate_text_llm",
                description: "Generate text using a loaded CoreML LLM model",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "model_name": ["type": "string", "description": "Name of the loaded LLM model"],
                        "prompt": ["type": "string", "description": "Text prompt for generation"],
                        "max_tokens": ["type": "integer", "description": "Maximum tokens to generate (default: 256)", "default": 256],
                        "temperature": ["type": "number", "description": "Sampling temperature (default: 0.7)", "default": 0.7]
                    ],
                    required: ["model_name", "prompt"]
                )
            ),
            Tool(
                name: "analyze_screen_with_llm",
                description: "Capture the screen and analyze it using a CoreML LLM with Vision data",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "model_name": ["type": "string", "description": "Name of the loaded LLM model"],
                        "instruction": ["type": "string", "description": "Analysis instruction for the LLM"],
                        "capture_type": ["type": "string", "description": "Type of capture: display, window, or application"],
                        "target_identifier": ["type": "string", "description": "Display ID, window ID/title, or app bundle identifier"],
                        "include_ocr": ["type": "boolean", "description": "Include OCR text extraction (default: true)"],
                        "include_classification": ["type": "boolean", "description": "Include image classification (default: true)"],
                        "include_objects": ["type": "boolean", "description": "Include object detection (default: false)"],
                        "max_response_tokens": ["type": "integer", "description": "Maximum response tokens (default: 512)"]
                    ],
                    required: ["model_name", "instruction"]
                )
            ),
            Tool(
                name: "intelligent_screen_summary",
                description: "Capture and analyze the screen using Vision framework for an intelligent summary",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "capture_type": ["type": "string", "description": "Type of capture: display, window, or application"],
                        "target_identifier": ["type": "string", "description": "Display ID, window ID/title, or app bundle identifier"]
                    ]
                )
            ),
            Tool(
                name: "extract_key_info",
                description: "Extract key information from OCR results",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "ocr_results": ["type": "array", "description": "Array of OCR result arrays"]
                    ],
                    required: ["ocr_results"]
                )
            ),
        ]
    }

    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]
        switch params.name {
        case "list_coreml_models":
            let directory = args["directory"]?.stringValue
            do {
                let models = try await CoreMLManager.shared.listAvailableModels(directory: directory)
                let jsonData = try JSONSerialization.data(withJSONObject: models)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Available CoreML models (\(models.count)):\n\(jsonString)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "load_coreml_model":
            guard let name = args["name"]?.stringValue,
                  let path = args["path"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: name and path required")], isError: true)
            }
            do {
                let message = try await CoreMLManager.shared.loadModel(name: name, path: path)
                return .init(content: [.text(message)], isError: false)
            } catch {
                return .init(content: [.text("Error loading model: \(error.localizedDescription)")], isError: true)
            }

        case "unload_coreml_model":
            guard let name = args["name"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: name required")], isError: true)
            }
            do {
                try await CoreMLManager.shared.unloadModel(name: name)
                return .init(content: [.text("Model '\(name)' unloaded successfully")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "get_model_info":
            guard let name = args["name"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: name required")], isError: true)
            }
            do {
                let metadata = try await CoreMLManager.shared.getModelMetadata(name: name)
                let jsonData = try JSONSerialization.data(withJSONObject: metadata)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                return .init(content: [.text("Model '\(name)' info:\n\(jsonString)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "generate_text_llm":
            guard let modelName = args["model_name"]?.stringValue,
                  let prompt = args["prompt"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: model_name and prompt required")], isError: true)
            }
            let maxTokens = args["max_tokens"]?.intValue ?? 256
            let temperature = args["temperature"]?.doubleValue ?? 0.7
            do {
                let response = try await CoreMLManager.shared.generateText(
                    modelName: modelName,
                    prompt: prompt,
                    maxTokens: maxTokens,
                    temperature: temperature
                )
                return .init(content: [.text("LLM Response:\n\(response)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "analyze_screen_with_llm":
            guard let modelName = args["model_name"]?.stringValue,
                  let instruction = args["instruction"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: model_name and instruction required")], isError: true)
            }
            let captureTypeStr = args["capture_type"]?.stringValue ?? "display"
            let targetIdentifier = args["target_identifier"]?.stringValue
            let includeOCR = args["include_ocr"]?.boolValue ?? true
            let includeClassification = args["include_classification"]?.boolValue ?? true
            let includeObjects = args["include_objects"]?.boolValue ?? false
            let maxTokens = args["max_response_tokens"]?.intValue ?? 512

            let captureType: ContinuousCaptureManager.CaptureType
            switch captureTypeStr.lowercased() {
            case "display": captureType = .display
            case "window": captureType = .window
            case "application", "app": captureType = .application
            default:
                return .init(content: [.text("Invalid capture_type. Must be: display, window, or application")], isError: true)
            }

            do {
                var analysisTypes: [RealtimeAnalyzer.AnalysisType] = []
                if includeClassification { analysisTypes.append(.classification(topK: 5)) }
                if includeObjects { analysisTypes.append(.objectDetection(minConfidence: 0.5)) }
                if includeOCR { analysisTypes.append(.ocr) }

                let screenContent = try await RealtimeAnalyzer.quickAnalyze(
                    captureType: captureType,
                    targetIdentifier: targetIdentifier,
                    analysisTypes: analysisTypes
                )

                let llmResult = try await CoreMLManager.shared.analyzeWithLLM(
                    modelName: modelName,
                    screenContent: screenContent,
                    instruction: instruction,
                    maxTokens: maxTokens
                )

                let jsonData = try JSONSerialization.data(withJSONObject: llmResult)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                return .init(content: [.text("Screen analysis with LLM:\n\(jsonString)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "intelligent_screen_summary":
            let captureTypeStr = args["capture_type"]?.stringValue ?? "display"
            let targetIdentifier = args["target_identifier"]?.stringValue

            let captureType: ContinuousCaptureManager.CaptureType
            switch captureTypeStr.lowercased() {
            case "display": captureType = .display
            case "window": captureType = .window
            case "application", "app": captureType = .application
            default:
                return .init(content: [.text("Invalid capture_type")], isError: true)
            }

            do {
                let analysisTypes: [RealtimeAnalyzer.AnalysisType] = [
                    .classification(topK: 5),
                    .ocr,
                    .objectDetection(minConfidence: 0.5)
                ]

                let results = try await RealtimeAnalyzer.quickAnalyze(
                    captureType: captureType,
                    targetIdentifier: targetIdentifier,
                    analysisTypes: analysisTypes
                )

                let classification = results["classification"] as? [[String: Any]]
                let ocr = results["ocr_text"] as? [[Any]]
                let objects = results["objects"] as? [[String: Any]]

                let summary = CoreMLManager.intelligentScreenAnalysis(
                    classificationResults: classification,
                    ocrResults: ocr,
                    objectResults: objects
                )

                let jsonData = try JSONSerialization.data(withJSONObject: summary)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                return .init(content: [.text("Intelligent screen summary:\n\(jsonString)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "extract_key_info":
            guard let ocrValue = args["ocr_results"]?.arrayValue else {
                return .init(content: [.text("Invalid parameters: ocr_results array required")], isError: true)
            }

            var ocrResults: [[Any]] = []
            for item in ocrValue {
                if let arr = item.arrayValue {
                    var converted: [Any] = []
                    for element in arr {
                        if let str = element.stringValue {
                            converted.append(str)
                        } else if let num = element.doubleValue {
                            converted.append(num)
                        } else if let subArr = element.arrayValue {
                            let subConverted = subArr.compactMap { $0.intValue }
                            converted.append(subConverted)
                        }
                    }
                    ocrResults.append(converted)
                }
            }

            let keyInfo = CoreMLManager.extractKeyInfo(ocrResults: ocrResults)

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: keyInfo)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                return .init(content: [.text("Extracted key information:\n\(jsonString)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        default:
            return nil
        }
    }
}
