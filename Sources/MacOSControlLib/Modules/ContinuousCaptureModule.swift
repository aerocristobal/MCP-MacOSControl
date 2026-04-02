import Foundation
import AppKit
import MCP

public enum ContinuousCaptureModule: ToolModule {
    private static var captureManager: ContinuousCaptureManager?

    public static var tools: [Tool] {
        [
            Tool(
                name: "start_continuous_capture",
                description: "Start continuous screen/window/app capture using ScreenCaptureKit",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "capture_type": ["type": "string", "description": "Type of capture: display, window, or application"],
                        "target_identifier": ["type": "string", "description": "Display ID, window ID/title, or app bundle identifier"],
                        "frame_rate": ["type": "integer", "description": "Capture frame rate (default: 30)", "default": 30]
                    ],
                    required: ["capture_type"]
                )
            ),
            Tool(
                name: "stop_continuous_capture",
                description: "Stop the active continuous capture session",
                inputSchema: jsonSchema(type: "object")
            ),
            Tool(
                name: "get_capture_frame",
                description: "Get the latest frame from continuous capture as base64 PNG",
                inputSchema: jsonSchema(type: "object")
            ),
            Tool(
                name: "list_capturable_displays",
                description: "List all available displays for capture",
                inputSchema: jsonSchema(type: "object")
            ),
            Tool(
                name: "list_capturable_windows",
                description: "List all capturable windows (ScreenCaptureKit)",
                inputSchema: jsonSchema(type: "object")
            ),
            Tool(
                name: "list_capturable_applications",
                description: "List all running applications available for capture",
                inputSchema: jsonSchema(type: "object")
            ),
        ]
    }

    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]
        switch params.name {
        case "start_continuous_capture":
            guard let captureTypeStr = args["capture_type"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: capture_type required")], isError: true)
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
                return .init(content: [.text("Invalid capture_type. Must be: display, window, or application")], isError: true)
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
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
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
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "get_capture_frame":
            if let manager = captureManager, let frame = manager.getLatestFrame() {
                let nsImage = NSImage(cgImage: frame, size: NSSize(width: frame.width, height: frame.height))
                guard let tiffData = nsImage.tiffRepresentation,
                      let bitmapImage = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                    return .init(content: [.text("Error: Failed to convert frame to PNG")], isError: true)
                }

                let base64 = pngData.base64EncodedString()
                return .init(
                    content: [.image(data: base64, mimeType: "image/png", annotations: nil, _meta: nil)],
                    isError: false
                )
            } else {
                return .init(content: [.text("No capture frame available. Start continuous capture first.")], isError: true)
            }

        case "list_capturable_displays":
            do {
                let displays = try await ContinuousCaptureManager.getAvailableDisplays()
                let jsonData = try JSONSerialization.data(withJSONObject: displays)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Available displays:\n\(jsonString)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "list_capturable_windows":
            do {
                let windows = try await ContinuousCaptureManager.getCapturableWindows()
                let jsonData = try JSONSerialization.data(withJSONObject: windows)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Capturable windows (\(windows.count)):\n\(jsonString)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "list_capturable_applications":
            do {
                let apps = try await ContinuousCaptureManager.getCapturableApplications()
                let jsonData = try JSONSerialization.data(withJSONObject: apps)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Capturable applications (\(apps.count)):\n\(jsonString)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        default:
            return nil
        }
    }
}
