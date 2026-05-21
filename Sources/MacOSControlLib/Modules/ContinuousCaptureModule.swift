import Foundation
import AppKit
import MCP

public enum ContinuousCaptureModule: ToolModule {
    private static var captureManager: ContinuousCaptureManager?

    public static var tools: [Tool] {
        [
            Tool(
                name: "start_continuous_capture",
                description: "Start a continuous ScreenCaptureKit session over a display, window, or application at the given frame rate. Use when you need a live feed instead of a single screenshot — typically paired with get_capture_frame and stop_continuous_capture. Returns a confirmation string with the capture type and frame rate.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "capture_type": [
                            "type": "string",
                            "description": "What to capture: one of display, window, or application.",
                            "enum": ["display", "window", "application"]
                        ],
                        "target_identifier": ["type": "string", "description": "Display ID, window ID / title, or app bundle identifier — depending on capture_type."],
                        "frame_rate": ["type": "integer", "description": "Capture frame rate in frames per second. Defaults to 30.", "default": 30]
                    ],
                    required: ["capture_type"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "stop_continuous_capture",
                description: "Stop the active ScreenCaptureKit capture session, if any. Use to release capture resources after collecting needed frames. Idempotent — calling when no session is active returns a benign \"no active capture\" message. Returns a confirmation string.",
                inputSchema: jsonSchema(type: "object"),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "get_capture_frame",
                description: "Fetch the most recent frame from the active continuous capture as base64 PNG image content. Use as the polling step in a capture loop. Not idempotent — successive calls advance through different frames as new ones arrive. Returns image content when a frame is available, error text otherwise.",
                inputSchema: jsonSchema(type: "object"),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "list_capturable_displays",
                description: "List displays available to ScreenCaptureKit, with display ID, name, and resolution. Use to pick a target_identifier before start_continuous_capture. Read-only; returns a JSON array.",
                inputSchema: jsonSchema(type: "object"),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "list_capturable_windows",
                description: "List windows available to ScreenCaptureKit, including title, window ID, and owning application bundle identifier. Use to pick a target_identifier before start_continuous_capture. Read-only; returns a JSON array.",
                inputSchema: jsonSchema(type: "object"),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "list_capturable_applications",
                description: "List running applications available to ScreenCaptureKit, with bundle identifier, name, and PID. Use to pick a target_identifier when capture_type=\"application\". Read-only; returns a JSON array.",
                inputSchema: jsonSchema(type: "object"),
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
        case "start_continuous_capture":
            guard let captureTypeStr = args["capture_type"]?.stringValue else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "capture_type required")
            }

            let captureType: ContinuousCaptureManager.CaptureType
            switch captureTypeStr.lowercased() {
            case "display":
                captureType = .display
            case "window":
                captureType = .window
            case "application", "app":
                captureType = .application
            default:
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "Invalid capture_type. Must be: display, window, or application")
            }

            let targetIdentifier = args["target_identifier"]?.stringValue
            let frameRate = args["frame_rate"]?.intValue ?? 30

            do {
                if captureManager == nil {
                    captureManager = ContinuousCaptureManager()
                }

                try await captureManager!.startCapture(type: captureType, targetIdentifier: targetIdentifier, frameRate: frameRate) { frame in
                    // Frame callback - stored for later retrieval
                }

                return .init(content: [.text("Started continuous capture (type: \(captureTypeStr), fps: \(frameRate))")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "stop_continuous_capture":
            do {
                if let manager = captureManager {
                    try await manager.stopCapture()
                    captureManager = nil
                    return .init(content: [.text("Stopped continuous capture")], isError: false)
                } else {
                    return .init(content: [.text("No active capture session")], isError: false)
                }
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "get_capture_frame":
            if let manager = captureManager, let frame = manager.getLatestFrame() {
                let nsImage = NSImage(cgImage: frame, size: NSSize(width: frame.width, height: frame.height))
                guard let tiffData = nsImage.tiffRepresentation,
                      let bitmapImage = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                    return MCPErrorResponseBuilder.shared.build(code: "backend_error", message: "Failed to convert frame to PNG")
                }

                let base64 = pngData.base64EncodedString()
                return .init(
                    content: [.image(data: base64, mimeType: "image/png", annotations: nil, _meta: nil)],
                    isError: false
                )
            } else {
                return MCPErrorResponseBuilder.shared.build(code: "backend_error", message: "No capture frame available. Start continuous capture first.")
            }

        case "list_capturable_displays":
            do {
                let displays = try await ContinuousCaptureManager.getAvailableDisplays()
                let jsonData = try JSONSerialization.data(withJSONObject: displays)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Available displays:\n\(jsonString)")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "list_capturable_windows":
            do {
                let windows = try await ContinuousCaptureManager.getCapturableWindows()
                let jsonData = try JSONSerialization.data(withJSONObject: windows)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Capturable windows (\(windows.count)):\n\(jsonString)")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "list_capturable_applications":
            do {
                let apps = try await ContinuousCaptureManager.getCapturableApplications()
                let jsonData = try JSONSerialization.data(withJSONObject: apps)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Capturable applications (\(apps.count)):\n\(jsonString)")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        default:
            return nil
        }
    }
}
