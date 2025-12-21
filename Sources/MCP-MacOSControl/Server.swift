import Foundation
import AppKit
import MCP

@main
struct MacOSControlServer {
    static var captureManager: ContinuousCaptureManager?

    static func main() async throws {
        // Create MCP server with capabilities
        let server = Server(
            name: "mcp-macos-control",
            version: "1.0.0",
            capabilities: .init(
                tools: .init(listChanged: true)
            )
        )

        // Register tool list handler
        await server.withMethodHandler(ListTools.self) { _ in
            let tools = Self.getToolDefinitions()
            return .init(tools: tools)
        }

        // Register tool call handler
        await server.withMethodHandler(CallTool.self) { params in
            return try await Self.handleToolCall(params: params)
        }

        // Start the server using stdio transport
        let transport = StdioTransport()
        do {
            try await server.start(transport: transport)
            await server.waitUntilCompleted()
        } catch {
            fputs("Error starting server: \(error)\n", stderr)
            exit(1)
        }
    }

    // MARK: - JSON Schema Helper

    static func jsonSchema(
        type: String,
        properties: [String: [String: Any]] = [:],
        required: [String] = []
    ) -> Value {
        var schema: [String: Value] = [
            "type": .string(type)
        ]

        if !properties.isEmpty {
            var props: [String: Value] = [:]
            for (key, value) in properties {
                var propDict: [String: Value] = [:]
                for (k, v) in value {
                    if let str = v as? String {
                        propDict[k] = .string(str)
                    } else if let num = v as? Int {
                        propDict[k] = .int(num)
                    } else if let num = v as? Double {
                        propDict[k] = .double(num)
                    } else if let bool = v as? Bool {
                        propDict[k] = .bool(bool)
                    }
                }
                props[key] = .object(propDict)
            }
            schema["properties"] = .object(props)
        }

        if !required.isEmpty {
            schema["required"] = .array(required.map { .string($0) })
        }

        return .object(schema)
    }

    // MARK: - Tool Definitions

    static func getToolDefinitions() -> [Tool] {
        return [
            Tool(
                name: "click_screen",
                description: "Click at the specified screen coordinates",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "x": ["type": "integer", "description": "X coordinate"],
                        "y": ["type": "integer", "description": "Y coordinate"]
                    ],
                    required: ["x", "y"]
                )
            ),
            Tool(
                name: "get_screen_size",
                description: "Get the current screen resolution",
                inputSchema: jsonSchema(type: "object")
            ),
            Tool(
                name: "type_text",
                description: "Type the specified text at the current cursor position",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "text": ["type": "string", "description": "Text to type"]
                    ],
                    required: ["text"]
                )
            ),
            Tool(
                name: "move_mouse",
                description: "Move the mouse to the specified screen coordinates",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "x": ["type": "integer", "description": "X coordinate"],
                        "y": ["type": "integer", "description": "Y coordinate"]
                    ],
                    required: ["x", "y"]
                )
            ),
            Tool(
                name: "mouse_down",
                description: "Hold down a mouse button ('left', 'right', 'middle')",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "button": ["type": "string", "description": "Mouse button (left, right, middle)", "default": "left"]
                    ]
                )
            ),
            Tool(
                name: "mouse_up",
                description: "Release a mouse button ('left', 'right', 'middle')",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "button": ["type": "string", "description": "Mouse button (left, right, middle)", "default": "left"]
                    ]
                )
            ),
            Tool(
                name: "drag_mouse",
                description: "Drag the mouse from one position to another",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "from_x": ["type": "integer", "description": "Start X coordinate"],
                        "from_y": ["type": "integer", "description": "Start Y coordinate"],
                        "to_x": ["type": "integer", "description": "End X coordinate"],
                        "to_y": ["type": "integer", "description": "End Y coordinate"],
                        "duration": ["type": "number", "description": "Duration in seconds", "default": 0.5]
                    ],
                    required: ["from_x", "from_y", "to_x", "to_y"]
                )
            ),
            Tool(
                name: "key_down",
                description: "Hold down a specific keyboard key until released",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "key": ["type": "string", "description": "Key to hold down"]
                    ],
                    required: ["key"]
                )
            ),
            Tool(
                name: "key_up",
                description: "Release a specific keyboard key",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "key": ["type": "string", "description": "Key to release"]
                    ],
                    required: ["key"]
                )
            ),
            Tool(
                name: "press_keys",
                description: "Press single keys, sequences, or combinations like [['cmd', 'c']]",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "keys": ["type": "array", "description": "Array of keys or key combinations to press"]
                    ],
                    required: ["keys"]
                )
            ),
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
            Tool(
                name: "list_windows",
                description: "List all open windows on the system",
                inputSchema: jsonSchema(type: "object")
            ),
            Tool(
                name: "activate_window",
                description: "Activate a window (bring it to the foreground) by matching its title",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "title_pattern": ["type": "string", "description": "Window title pattern"],
                        "use_regex": ["type": "boolean", "description": "Use regex for pattern matching", "default": false],
                        "threshold": ["type": "integer", "description": "Fuzzy match threshold (0-100)", "default": 60]
                    ],
                    required: ["title_pattern"]
                )
            ),
            Tool(
                name: "wait_milliseconds",
                description: "Wait for a specified number of milliseconds",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "milliseconds": ["type": "integer", "description": "Milliseconds to wait"]
                    ],
                    required: ["milliseconds"]
                )
            ),
            // Continuous Capture Tools
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
            // Vision Framework Tools
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
            )
        ]
    }

    // MARK: - Tool Call Handler

    static func handleToolCall(params: CallTool.Parameters) async throws -> CallTool.Result {
        let args = params.arguments ?? [:]

        switch params.name {
        case "click_screen":
            guard let x = args["x"]?.intValue,
                  let y = args["y"]?.intValue else {
                return .init(content: [.text("Invalid parameters: x and y coordinates required")], isError: true)
            }
            do {
                try MouseControl.click(x: x, y: y)
                return .init(content: [.text("Clicked at (\(x), \(y))")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "get_screen_size":
            let size = MouseControl.getScreenSize()
            return .init(content: [.text("Screen size: \(size.width)x\(size.height)")], isError: false)

        case "type_text":
            guard let text = args["text"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: text required")], isError: true)
            }
            do {
                try KeyboardControl.typeText(text: text)
                return .init(content: [.text("Typed: \(text)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "move_mouse":
            guard let x = args["x"]?.intValue,
                  let y = args["y"]?.intValue else {
                return .init(content: [.text("Invalid parameters: x and y coordinates required")], isError: true)
            }
            do {
                try MouseControl.moveMouse(x: x, y: y)
                return .init(content: [.text("Moved mouse to (\(x), \(y))")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "mouse_down":
            let button = args["button"]?.stringValue ?? "left"
            do {
                try MouseControl.mouseDown(button: button)
                return .init(content: [.text("Mouse button \(button) down")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "mouse_up":
            let button = args["button"]?.stringValue ?? "left"
            do {
                try MouseControl.mouseUp(button: button)
                return .init(content: [.text("Mouse button \(button) up")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "drag_mouse":
            guard let fromX = args["from_x"]?.intValue,
                  let fromY = args["from_y"]?.intValue,
                  let toX = args["to_x"]?.intValue,
                  let toY = args["to_y"]?.intValue else {
                return .init(content: [.text("Invalid parameters: from_x, from_y, to_x, to_y required")], isError: true)
            }
            let duration = args["duration"]?.doubleValue ?? 0.5
            do {
                try MouseControl.dragMouse(fromX: fromX, fromY: fromY, toX: toX, toY: toY, duration: duration)
                return .init(content: [.text("Dragged from (\(fromX), \(fromY)) to (\(toX), \(toY))")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "key_down":
            guard let key = args["key"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: key required")], isError: true)
            }
            do {
                try KeyboardControl.keyDown(key: key)
                return .init(content: [.text("Key \(key) down")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "key_up":
            guard let key = args["key"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: key required")], isError: true)
            }
            do {
                try KeyboardControl.keyUp(key: key)
                return .init(content: [.text("Key \(key) up")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "press_keys":
            guard let keysValue = args["keys"]?.arrayValue else {
                return .init(content: [.text("Invalid parameters: keys array required")], isError: true)
            }
            // Convert [Value] to [Any]
            let keys = keysValue.map { value -> Any in
                if let str = value.stringValue {
                    return str
                } else if let arr = value.arrayValue {
                    return arr.compactMap { $0.stringValue }
                }
                return value
            }
            do {
                try KeyboardControl.pressKeys(keys: keys)
                return .init(content: [.text("Pressed keys")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

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
                    content: [.image(data: base64, mimeType: "image/png", metadata: nil)],
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

        case "list_windows":
            do {
                let windows = try WindowManagement.listWindows()
                let jsonData = try JSONSerialization.data(withJSONObject: windows)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(
                    content: [.text("Found \(windows.count) windows\n\(jsonString)")],
                    isError: false
                )
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "activate_window":
            guard let titlePattern = args["title_pattern"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: title_pattern required")], isError: true)
            }
            let useRegex = args["use_regex"]?.boolValue ?? false
            let threshold = args["threshold"]?.intValue ?? 60

            do {
                try WindowManagement.activateWindow(titlePattern: titlePattern, useRegex: useRegex, threshold: threshold)
                return .init(content: [.text("Activated window: \(titlePattern)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "wait_milliseconds":
            guard let milliseconds = args["milliseconds"]?.intValue else {
                return .init(content: [.text("Invalid parameters: milliseconds required")], isError: true)
            }
            let nanoseconds = UInt64(milliseconds) * 1_000_000
            try await Task.sleep(nanoseconds: nanoseconds)
            return .init(content: [.text("Waited \(milliseconds)ms")], isError: false)

        // Continuous Capture Tools
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
                // Convert CGImage to PNG data
                let nsImage = NSImage(cgImage: frame, size: NSSize(width: frame.width, height: frame.height))
                guard let tiffData = nsImage.tiffRepresentation,
                      let bitmapImage = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                    return .init(content: [.text("Error: Failed to convert frame to PNG")], isError: true)
                }

                let base64 = pngData.base64EncodedString()
                return .init(
                    content: [.image(data: base64, mimeType: "image/png", metadata: nil)],
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

        // Vision Framework Tools
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
            return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
        }
    }
}
