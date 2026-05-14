import Foundation
import MCP

public enum RealtimeModule: ToolModule {
    private static var realtimeAnalyzer: RealtimeAnalyzer?

    public static var tools: [Tool] {
        [
            Tool(
                name: "analyze_screen_now",
                description: "Run a one-shot Vision analysis on the screen and return the configured results. Use as a synchronous alternative to start_screen_monitoring when you need a single snapshot of what's on screen. Non-idempotent (live screen). Read-only with respect to the system. Returns a JSON object with the requested analyses.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "capture_type": [
                            "type": "string",
                            "description": "Scope of the screen capture: one of display, window, or application.",
                            "enum": ["display", "window", "application"]
                        ],
                        "target_identifier": ["type": "string", "description": "Display ID, window ID / title, or app bundle identifier — depending on capture_type."],
                        "include_classification": ["type": "boolean", "description": "Include image classification. Defaults to true.", "default": true],
                        "include_objects": ["type": "boolean", "description": "Include object detection. Defaults to false.", "default": false],
                        "include_rectangles": ["type": "boolean", "description": "Include rectangle detection. Defaults to false.", "default": false],
                        "include_faces": ["type": "boolean", "description": "Include face detection. Defaults to false.", "default": false],
                        "include_text": ["type": "boolean", "description": "Include OCR text extraction. Defaults to false.", "default": false],
                        "include_saliency": ["type": "boolean", "description": "Include saliency detection. Defaults to false.", "default": false]
                    ]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "start_screen_monitoring",
                description: "Start a continuous Vision analysis pipeline over a display, window, or application. Use to track on-screen changes asynchronously — pair with get_monitoring_results and stop_screen_monitoring. Returns a confirmation string with the configured frame rate and capture target.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "capture_type": [
                            "type": "string",
                            "description": "Scope of the screen capture: one of display, window, or application.",
                            "enum": ["display", "window", "application"]
                        ],
                        "target_identifier": ["type": "string", "description": "Display ID, window ID / title, or app bundle identifier — depending on capture_type."],
                        "frame_rate": ["type": "integer", "description": "Analyses per second; lower values reduce CPU load. Defaults to 10.", "default": 10],
                        "include_classification": ["type": "boolean", "description": "Include image classification. Defaults to true.", "default": true],
                        "include_objects": ["type": "boolean", "description": "Include object detection. Defaults to false.", "default": false],
                        "include_rectangles": ["type": "boolean", "description": "Include rectangle detection. Defaults to false.", "default": false],
                        "include_faces": ["type": "boolean", "description": "Include face detection. Defaults to false.", "default": false],
                        "include_text": ["type": "boolean", "description": "Include OCR text extraction. Defaults to false.", "default": false]
                    ]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "get_monitoring_results",
                description: "Fetch the latest Vision analysis results from an active screen-monitoring session. Use to poll for the most recent classification / OCR / detection output. Read-only with respect to the system; non-idempotent (latest frame changes). Returns a JSON object.",
                inputSchema: jsonSchema(type: "object"),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "stop_screen_monitoring",
                description: "Stop the active screen-monitoring session, if any, and release its resources. Idempotent — calling when no session is active returns a benign \"no active monitoring\" message. Returns a confirmation string.",
                inputSchema: jsonSchema(type: "object"),
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
        case "analyze_screen_now":
            let captureTypeStr = args["capture_type"]?.stringValue ?? "display"
            let captureType: ContinuousCaptureManager.CaptureType
            switch captureTypeStr.lowercased() {
            case "display": captureType = .display
            case "window": captureType = .window
            case "application", "app": captureType = .application
            default:
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "Invalid capture_type. Must be: display, window, or application")
            }
            let targetIdentifier = args["target_identifier"]?.stringValue
            var analysisTypes: [RealtimeAnalyzer.AnalysisType] = []
            if args["include_classification"]?.boolValue ?? true { analysisTypes.append(.classification(topK: 5)) }
            if args["include_objects"]?.boolValue ?? false { analysisTypes.append(.objectDetection(minConfidence: 0.5)) }
            if args["include_rectangles"]?.boolValue ?? false { analysisTypes.append(.rectangles(minConfidence: 0.5)) }
            if args["include_faces"]?.boolValue ?? false { analysisTypes.append(.faces) }
            if args["include_text"]?.boolValue ?? false { analysisTypes.append(.ocr) }
            if args["include_saliency"]?.boolValue ?? false { analysisTypes.append(.saliency) }
            do {
                let results = try await RealtimeAnalyzer.quickAnalyze(
                    captureType: captureType,
                    targetIdentifier: targetIdentifier,
                    analysisTypes: analysisTypes
                )
                let jsonData = try JSONSerialization.data(withJSONObject: results)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                return .init(content: [.text("Screen analysis completed:\n\(jsonString)")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "start_screen_monitoring":
            let captureTypeStr = args["capture_type"]?.stringValue ?? "display"
            let captureType: ContinuousCaptureManager.CaptureType
            switch captureTypeStr.lowercased() {
            case "display": captureType = .display
            case "window": captureType = .window
            case "application", "app": captureType = .application
            default:
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "Invalid capture_type. Must be: display, window, or application")
            }
            let targetIdentifier = args["target_identifier"]?.stringValue
            let frameRate = args["frame_rate"]?.intValue ?? 10
            var analysisTypes: [RealtimeAnalyzer.AnalysisType] = []
            if args["include_classification"]?.boolValue ?? true { analysisTypes.append(.classification(topK: 5)) }
            if args["include_objects"]?.boolValue ?? false { analysisTypes.append(.objectDetection(minConfidence: 0.5)) }
            if args["include_rectangles"]?.boolValue ?? false { analysisTypes.append(.rectangles(minConfidence: 0.5)) }
            if args["include_faces"]?.boolValue ?? false { analysisTypes.append(.faces) }
            if args["include_text"]?.boolValue ?? false { analysisTypes.append(.ocr) }
            do {
                if realtimeAnalyzer == nil { realtimeAnalyzer = RealtimeAnalyzer() }
                try await realtimeAnalyzer!.startRealtimeAnalysis(
                    captureType: captureType,
                    targetIdentifier: targetIdentifier,
                    frameRate: frameRate,
                    analysisTypes: analysisTypes
                )
                return .init(content: [.text("Started screen monitoring (type: \(captureTypeStr), fps: \(frameRate))")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "get_monitoring_results":
            if let analyzer = realtimeAnalyzer {
                let results = analyzer.getLatestAnalysis()
                if results.isEmpty {
                    return .init(content: [.text("No analysis results available yet")], isError: false)
                }
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: results)
                    let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                    return .init(content: [.text("Latest monitoring results:\n\(jsonString)")], isError: false)
                } catch {
                    return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
                }
            } else {
                return MCPErrorResponseBuilder.shared.build(code: "backend_error", message: "No active monitoring session. Use start_screen_monitoring first.")
            }

        case "stop_screen_monitoring":
            do {
                if let analyzer = realtimeAnalyzer {
                    try await analyzer.stopRealtimeAnalysis()
                    realtimeAnalyzer = nil
                    return .init(content: [.text("Stopped screen monitoring")], isError: false)
                } else {
                    return .init(content: [.text("No active monitoring session")], isError: false)
                }
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        default:
            return nil
        }
    }
}
