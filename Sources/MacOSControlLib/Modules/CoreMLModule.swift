import Foundation
import MCP

public enum CoreMLModule: ToolModule {
    public static var tools: [Tool] {
        [
            Tool(
                name: "list_coreml_models",
                description: "List CoreML models discoverable on the system, optionally restricted to a directory. Use to see what's available before calling load_coreml_model. Read-only; returns a JSON array of model metadata.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "directory": ["type": "string", "description": "Optional directory to search. When omitted, searches the standard model locations."]
                    ]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "load_coreml_model",
                description: "Load a CoreML model from disk into in-process memory under a user-chosen name. Use before generate_text_llm or analyze_screen_with_llm. Idempotent — loading the same name + path twice is a no-op. Returns a confirmation string with the load result.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "name": ["type": "string", "description": "Handle used to reference the model in later tool calls."],
                        "path": ["type": "string", "description": "File path to the .mlmodel or .mlmodelc bundle to load."]
                    ],
                    required: ["name", "path"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "unload_coreml_model",
                description: "Free a previously-loaded CoreML model from memory. Use to release RAM once you no longer need a model. Idempotent — unloading an already-unloaded name is a no-op. Returns a confirmation string.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "name": ["type": "string", "description": "Handle of the model to unload (matches the name used in load_coreml_model)."]
                    ],
                    required: ["name"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "get_model_info",
                description: "Return metadata for a loaded CoreML model — input / output schemas, descriptions, and version. Use to understand how to feed and interpret the model. Read-only; returns a JSON object.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "name": ["type": "string", "description": "Handle of the loaded model to introspect."]
                    ],
                    required: ["name"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "generate_text_llm",
                description: "Generate text from a prompt using a loaded CoreML LLM. Use for on-device language tasks. Sampling means repeated calls with the same input may produce different outputs (non-idempotent). Read-only with respect to the system. Returns the generated text as a string.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "model_name": ["type": "string", "description": "Handle of the loaded LLM model."],
                        "prompt": ["type": "string", "description": "Prompt text to feed the model."],
                        "max_tokens": ["type": "integer", "description": "Maximum number of tokens to generate. Defaults to 256.", "default": 256],
                        "temperature": ["type": "number", "description": "Sampling temperature; lower = more deterministic. Defaults to 0.7.", "default": 0.7]
                    ],
                    required: ["model_name", "prompt"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "analyze_screen_with_llm",
                description: "Capture the screen, run a configurable Vision / OCR pipeline, and feed the result to a loaded CoreML LLM with the given instruction. Use for end-to-end visual reasoning on the current screen. Non-idempotent (live screen + sampling). Read-only with respect to the system. Returns a JSON object with the LLM's response.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "model_name": ["type": "string", "description": "Handle of the loaded LLM model."],
                        "instruction": ["type": "string", "description": "What the LLM should analyze about the captured screen."],
                        "capture_type": [
                            "type": "string",
                            "description": "Scope of the screen capture: one of display, window, or application.",
                            "enum": ["display", "window", "application"]
                        ],
                        "target_identifier": ["type": "string", "description": "Display ID, window ID / title, or app bundle identifier — depending on capture_type."],
                        "include_ocr": ["type": "boolean", "description": "Include OCR text extraction in the pipeline. Defaults to true.", "default": true],
                        "include_classification": ["type": "boolean", "description": "Include image classification. Defaults to true.", "default": true],
                        "include_objects": ["type": "boolean", "description": "Include object detection. Defaults to false.", "default": false],
                        "max_response_tokens": ["type": "integer", "description": "Maximum response tokens for the LLM. Defaults to 512.", "default": 512]
                    ],
                    required: ["model_name", "instruction"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "intelligent_screen_summary",
                description: "Capture the screen and produce a structured Vision-based summary (classification + OCR + object detection) without invoking an LLM. Use as a lightweight alternative to analyze_screen_with_llm when you only need raw signals. Non-idempotent (live screen). Read-only with respect to the system. Returns a JSON summary.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "capture_type": [
                            "type": "string",
                            "description": "Scope of the screen capture: one of display, window, or application.",
                            "enum": ["display", "window", "application"]
                        ],
                        "target_identifier": ["type": "string", "description": "Display ID, window ID / title, or app bundle identifier — depending on capture_type."]
                    ]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "extract_key_info",
                description: "Pure function over OCR results — distills key-value-like text into a structured object (titles, emails, URLs, numbers, etc.) without any system access. Use to post-process a take_screenshot_with_ocr response. Idempotent for a given input. Returns a JSON object.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "ocr_results": ["type": "array", "description": "Array of [polygon, text, confidence] arrays as returned by take_screenshot_with_ocr."]
                    ],
                    required: ["ocr_results"]
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
        case "list_coreml_models":
            let directory = args["directory"]?.stringValue
            do {
                let models = try await CoreMLManager.shared.listAvailableModels(directory: directory)
                let jsonData = try JSONSerialization.data(withJSONObject: models)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Available CoreML models (\(models.count)):\n\(jsonString)")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "load_coreml_model":
            guard let name = args["name"]?.stringValue,
                  let path = args["path"]?.stringValue else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "name and path required")
            }
            do {
                let message = try await CoreMLManager.shared.loadModel(name: name, path: path)
                return .init(content: [.text(message)], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "unload_coreml_model":
            guard let name = args["name"]?.stringValue else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "name required")
            }
            do {
                try await CoreMLManager.shared.unloadModel(name: name)
                return .init(content: [.text("Model '\(name)' unloaded successfully")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "get_model_info":
            guard let name = args["name"]?.stringValue else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "name required")
            }
            do {
                let metadata = try await CoreMLManager.shared.getModelMetadata(name: name)
                let jsonData = try JSONSerialization.data(withJSONObject: metadata)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                return .init(content: [.text("Model '\(name)' info:\n\(jsonString)")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "generate_text_llm":
            guard let modelName = args["model_name"]?.stringValue,
                  let prompt = args["prompt"]?.stringValue else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "model_name and prompt required")
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
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "analyze_screen_with_llm":
            guard let modelName = args["model_name"]?.stringValue,
                  let instruction = args["instruction"]?.stringValue else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "model_name and instruction required")
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
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "Invalid capture_type. Must be: display, window, or application")
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
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
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
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "Invalid capture_type")
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
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "extract_key_info":
            guard let ocrValue = args["ocr_results"]?.arrayValue else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "ocr_results array required")
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
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        default:
            return nil
        }
    }
}
