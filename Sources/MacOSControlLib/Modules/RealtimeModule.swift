import Foundation
import MCP

public enum RealtimeModule: ToolModule {
    private static var realtimeAnalyzer: RealtimeAnalyzer?

    public static var tools: [Tool] {
        [
            Tool(
                name: "analyze_screen_now",
                description: "Perform a one-shot screen analysis using Vision framework",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "capture_type": ["type": "string", "description": "Type of capture: display, window, or application"],
                        "target_identifier": ["type": "string", "description": "Display ID, window ID/title, or app bundle identifier"],
                        "include_classification": ["type": "boolean", "description": "Include image classification (default: true)"],
                        "include_objects": ["type": "boolean", "description": "Include object detection (default: false)"],
                        "include_rectangles": ["type": "boolean", "description": "Include rectangle detection (default: false)"],
                        "include_faces": ["type": "boolean", "description": "Include face detection (default: false)"],
                        "include_text": ["type": "boolean", "description": "Include OCR text extraction (default: false)"],
                        "include_saliency": ["type": "boolean", "description": "Include saliency detection (default: false)"]
                    ]
                )
            ),
            Tool(
                name: "start_screen_monitoring",
                description: "Start continuous screen monitoring with real-time Vision analysis",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "capture_type": ["type": "string", "description": "Type of capture: display, window, or application"],
                        "target_identifier": ["type": "string", "description": "Display ID, window ID/title, or app bundle identifier"],
                        "frame_rate": ["type": "integer", "description": "Analysis frame rate (default: 10)", "default": 10],
                        "include_classification": ["type": "boolean", "description": "Include image classification (default: true)"],
                        "include_objects": ["type": "boolean", "description": "Include object detection (default: false)"],
                        "include_rectangles": ["type": "boolean", "description": "Include rectangle detection (default: false)"],
                        "include_faces": ["type": "boolean", "description": "Include face detection (default: false)"],
                        "include_text": ["type": "boolean", "description": "Include OCR text extraction (default: false)"]
                    ]
                )
            ),
            Tool(
                name: "get_monitoring_results",
                description: "Get the latest results from active screen monitoring",
                inputSchema: jsonSchema(type: "object")
            ),
            Tool(
                name: "stop_screen_monitoring",
                description: "Stop the active screen monitoring session",
                inputSchema: jsonSchema(type: "object")
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
                return .init(content: [.text("Invalid capture_type. Must be: display, window, or application")], isError: true)
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
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "start_screen_monitoring":
            let captureTypeStr = args["capture_type"]?.stringValue ?? "display"
            let captureType: ContinuousCaptureManager.CaptureType
            switch captureTypeStr.lowercased() {
            case "display": captureType = .display
            case "window": captureType = .window
            case "application", "app": captureType = .application
            default:
                return .init(content: [.text("Invalid capture_type. Must be: display, window, or application")], isError: true)
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
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
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
                    return .init(content: [.text("Error serializing results: \(error.localizedDescription)")], isError: true)
                }
            } else {
                return .init(content: [.text("No active monitoring session. Use start_screen_monitoring first.")], isError: true)
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
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        default:
            return nil
        }
    }
}
