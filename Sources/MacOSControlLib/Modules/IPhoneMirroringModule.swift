import Foundation
import AppKit
import MCP

public enum IPhoneMirroringModule: ToolModule {
    public static var tools: [Tool] {
        [
            // Status & Control
            Tool(
                name: "iphone_status",
                description: "Check if iPhone Mirroring is running and get window information",
                inputSchema: jsonSchema(type: "object")
            ),
            Tool(
                name: "iphone_launch",
                description: "Launch or activate the iPhone Mirroring app",
                inputSchema: jsonSchema(type: "object")
            ),
            Tool(
                name: "iphone_calibrate",
                description: "Force re-calibration of the iPhone screen content area detection",
                inputSchema: jsonSchema(type: "object")
            ),

            // Tap Gestures
            Tool(
                name: "iphone_tap",
                description: "Tap at normalized coordinates (0-1) on the iPhone screen",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "x": ["type": "number", "description": "Normalized X coordinate (0.0-1.0)"],
                        "y": ["type": "number", "description": "Normalized Y coordinate (0.0-1.0)"]
                    ],
                    required: ["x", "y"]
                )
            ),
            Tool(
                name: "iphone_double_tap",
                description: "Double-tap at normalized coordinates on the iPhone screen",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "x": ["type": "number", "description": "Normalized X coordinate (0.0-1.0)"],
                        "y": ["type": "number", "description": "Normalized Y coordinate (0.0-1.0)"]
                    ],
                    required: ["x", "y"]
                )
            ),
            Tool(
                name: "iphone_long_press",
                description: "Long-press at normalized coordinates on the iPhone screen",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "x": ["type": "number", "description": "Normalized X coordinate (0.0-1.0)"],
                        "y": ["type": "number", "description": "Normalized Y coordinate (0.0-1.0)"],
                        "duration": ["type": "number", "description": "Press duration in seconds", "default": 1.0]
                    ],
                    required: ["x", "y"]
                )
            ),

            // Swipe & Scroll
            Tool(
                name: "iphone_swipe",
                description: "Swipe on the iPhone screen with ease-in-out curve",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "start_x": ["type": "number", "description": "Start X (0.0-1.0)"],
                        "start_y": ["type": "number", "description": "Start Y (0.0-1.0)"],
                        "end_x": ["type": "number", "description": "End X (0.0-1.0)"],
                        "end_y": ["type": "number", "description": "End Y (0.0-1.0)"],
                        "duration": ["type": "number", "description": "Swipe duration in seconds", "default": 0.5]
                    ],
                    required: ["start_x", "start_y", "end_x", "end_y"]
                )
            ),
            Tool(
                name: "iphone_scroll",
                description: "Send scroll wheel events to the iPhone Mirroring window",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "delta_x": ["type": "integer", "description": "Horizontal scroll amount", "default": 0],
                        "delta_y": ["type": "integer", "description": "Vertical scroll amount (positive=down)", "default": 0]
                    ]
                )
            ),

            // Text Input
            Tool(
                name: "iphone_type_text",
                description: "Type text into a focused iOS text field via clipboard paste",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "text": ["type": "string", "description": "Text to type"]
                    ],
                    required: ["text"]
                )
            ),
            Tool(
                name: "iphone_clear_text",
                description: "Clear the focused iOS text field (Cmd+A then Delete)",
                inputSchema: jsonSchema(type: "object")
            ),
            Tool(
                name: "iphone_press_key",
                description: "Send a key event to the iPhone Mirroring window",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "key": ["type": "string", "description": "Key to press (e.g., return, escape, tab)"],
                        "modifiers": ["type": "array", "description": "Optional modifier keys (cmd, shift, ctrl, alt)"]
                    ],
                    required: ["key"]
                )
            ),

            // Navigation
            Tool(
                name: "iphone_home",
                description: "Go to iPhone home screen (Cmd+1)",
                inputSchema: jsonSchema(type: "object")
            ),
            Tool(
                name: "iphone_app_switcher",
                description: "Open iPhone App Switcher (Cmd+2)",
                inputSchema: jsonSchema(type: "object")
            ),
            Tool(
                name: "iphone_spotlight",
                description: "Open iPhone Spotlight search (Cmd+3)",
                inputSchema: jsonSchema(type: "object")
            ),

            // Perception
            Tool(
                name: "iphone_screenshot",
                description: "Capture the iPhone screen content (cropped to phone display area)",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "save_to_downloads": ["type": "boolean", "description": "Save screenshot to Downloads", "default": false]
                    ]
                )
            ),
            Tool(
                name: "iphone_screenshot_with_ocr",
                description: "Capture iPhone screen and extract text with OCR (coordinates normalized 0-1)",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "save_to_downloads": ["type": "boolean", "description": "Save screenshot to Downloads", "default": false]
                    ]
                )
            ),
            Tool(
                name: "iphone_analyze_screen_now",
                description: "Run Vision analysis on the iPhone screen with normalized coordinates",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "include_classification": ["type": "boolean", "description": "Include scene classification", "default": true],
                        "include_objects": ["type": "boolean", "description": "Include object detection", "default": false],
                        "include_rectangles": ["type": "boolean", "description": "Include rectangle detection", "default": false],
                        "include_text": ["type": "boolean", "description": "Include OCR", "default": false],
                        "include_saliency": ["type": "boolean", "description": "Include saliency detection", "default": false]
                    ]
                )
            ),
            Tool(
                name: "iphone_analyze_with_llm",
                description: "Analyze iPhone screen with on-device CoreML LLM",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "model_name": ["type": "string", "description": "Name of loaded CoreML LLM model"],
                        "instruction": ["type": "string", "description": "What to analyze on the iPhone screen"],
                        "max_tokens": ["type": "integer", "description": "Max response tokens", "default": 512]
                    ],
                    required: ["model_name", "instruction"]
                )
            ),

            // Convenience
            Tool(
                name: "iphone_open_app",
                description: "Open an iOS app by name via Spotlight search",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "app_name": ["type": "string", "description": "Name of the iOS app to open"]
                    ],
                    required: ["app_name"]
                )
            ),
            Tool(
                name: "iphone_wait_for_text",
                description: "Poll iPhone screen OCR until specific text appears (returns normalized coordinates)",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "text": ["type": "string", "description": "Text to wait for (case-insensitive)"],
                        "timeout_ms": ["type": "integer", "description": "Maximum wait time in milliseconds", "default": 5000],
                        "poll_interval_ms": ["type": "integer", "description": "Time between polls in milliseconds", "default": 500]
                    ],
                    required: ["text"]
                )
            ),
            Tool(
                name: "iphone_reconnect",
                description: "Wait for iPhone Mirroring to reconnect after a disconnect",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "timeout_ms": ["type": "integer", "description": "Maximum wait time in milliseconds", "default": 30000]
                    ]
                )
            ),
        ]
    }

    // MARK: - Handler

    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]

        switch params.name {
        // MARK: Status & Control
        case "iphone_status":
            let running = MirroringWindowDetector.isMirroringRunning()
            var status: [String: Any] = ["running": running]

            if running {
                do {
                    let (windowID, bounds) = try MirroringWindowDetector.findMirroringWindow()
                    status["windowId"] = Int(windowID)
                    status["position"] = ["x": bounds.minX, "y": bounds.minY]
                    status["size"] = ["width": bounds.width, "height": bounds.height]
                    status["connected"] = MirroringWindowDetector.isConnected()
                } catch {
                    status["window_error"] = error.localizedDescription
                }
            }

            let jsonData = try JSONSerialization.data(withJSONObject: status)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            return .init(content: [.text("iPhone Mirroring status:\n\(jsonString)")], isError: false)

        case "iphone_launch":
            do {
                if MirroringWindowDetector.isMirroringRunning() {
                    try await MirroringWindowDetector.activateAndFocus()
                } else {
                    try MirroringWindowDetector.launchMirroringApp()
                    // Wait for app to start
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2s
                    try await MirroringWindowDetector.activateAndFocus()
                }
                let (windowID, bounds) = try MirroringWindowDetector.findMirroringWindow()
                return .init(content: [.text("iPhone Mirroring active (window \(windowID), \(Int(bounds.width))x\(Int(bounds.height)))")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        case "iphone_calibrate":
            do {
                CoordinateTranslator.clearCache()
                let contentRect = try await CoordinateTranslator.calibrate()
                let result: [String: Any] = [
                    "content_rect": [
                        "x": contentRect.minX,
                        "y": contentRect.minY,
                        "width": contentRect.width,
                        "height": contentRect.height
                    ],
                    "insets": [
                        "top": contentRect.minY - (MirroringWindowDetector.cachedWindowBounds?.minY ?? 0),
                        "left": contentRect.minX - (MirroringWindowDetector.cachedWindowBounds?.minX ?? 0)
                    ]
                ]
                let jsonData = try JSONSerialization.data(withJSONObject: result)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                return .init(content: [.text("Calibration complete:\n\(jsonString)")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        // MARK: Tap Gestures
        case "iphone_tap":
            guard let x = args["x"]?.doubleValue,
                  let y = args["y"]?.doubleValue else {
                return .init(content: [.text("Invalid parameters: x and y (number) required")], isError: true)
            }
            do {
                try await GestureEngine.tap(x: x, y: y)
                return .init(content: [.text("Tapped at (\(x), \(y))")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        case "iphone_double_tap":
            guard let x = args["x"]?.doubleValue,
                  let y = args["y"]?.doubleValue else {
                return .init(content: [.text("Invalid parameters: x and y (number) required")], isError: true)
            }
            do {
                try await GestureEngine.doubleTap(x: x, y: y)
                return .init(content: [.text("Double-tapped at (\(x), \(y))")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        case "iphone_long_press":
            guard let x = args["x"]?.doubleValue,
                  let y = args["y"]?.doubleValue else {
                return .init(content: [.text("Invalid parameters: x and y (number) required")], isError: true)
            }
            let duration = args["duration"]?.doubleValue ?? 1.0
            do {
                try await GestureEngine.longPress(x: x, y: y, duration: duration)
                return .init(content: [.text("Long-pressed at (\(x), \(y)) for \(duration)s")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        // MARK: Swipe & Scroll
        case "iphone_swipe":
            guard let startX = args["start_x"]?.doubleValue,
                  let startY = args["start_y"]?.doubleValue,
                  let endX = args["end_x"]?.doubleValue,
                  let endY = args["end_y"]?.doubleValue else {
                return .init(content: [.text("Invalid parameters: start_x, start_y, end_x, end_y required")], isError: true)
            }
            let duration = args["duration"]?.doubleValue ?? 0.5
            do {
                try await GestureEngine.swipe(startX: startX, startY: startY, endX: endX, endY: endY, duration: duration)
                return .init(content: [.text("Swiped from (\(startX), \(startY)) to (\(endX), \(endY))")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        case "iphone_scroll":
            let deltaX = Int32(args["delta_x"]?.intValue ?? 0)
            let deltaY = Int32(args["delta_y"]?.intValue ?? 0)
            do {
                try await GestureEngine.scroll(deltaX: deltaX, deltaY: deltaY)
                return .init(content: [.text("Scrolled (dx=\(deltaX), dy=\(deltaY))")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        // MARK: Text Input
        case "iphone_type_text":
            guard let text = args["text"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: text required")], isError: true)
            }
            do {
                try await IPhoneTextInput.typeText(text)
                return .init(content: [.text("Typed: \(text)")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        case "iphone_clear_text":
            do {
                try await IPhoneTextInput.clearText()
                return .init(content: [.text("Cleared text field")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        case "iphone_press_key":
            guard let key = args["key"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: key required")], isError: true)
            }
            let modifiers = args["modifiers"]?.arrayValue?.compactMap { $0.stringValue } ?? []
            do {
                try await IPhoneTextInput.pressKey(key: key, modifiers: modifiers)
                return .init(content: [.text("Pressed key: \(modifiers.isEmpty ? key : (modifiers.joined(separator: "+") + "+" + key))")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        // MARK: Navigation
        case "iphone_home":
            do {
                try await IOSNavigation.home()
                return .init(content: [.text("Sent Home (Cmd+1)")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        case "iphone_app_switcher":
            do {
                try await IOSNavigation.appSwitcher()
                return .init(content: [.text("Sent App Switcher (Cmd+2)")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        case "iphone_spotlight":
            do {
                try await IOSNavigation.spotlight()
                return .init(content: [.text("Sent Spotlight (Cmd+3)")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        // MARK: Perception
        case "iphone_screenshot":
            do {
                let imageData = try await captureIPhoneScreen()
                let base64 = imageData.base64EncodedString()
                return .init(
                    content: [.image(data: base64, mimeType: "image/png", annotations: nil, _meta: nil)],
                    isError: false
                )
            } catch let error as MCPError {
                return error.toResult()
            }

        case "iphone_screenshot_with_ocr":
            do {
                let imageData = try await captureIPhoneScreen()
                let ocrResults = try await OCRProcessor.performOCR(on: imageData)

                // Get content rect dimensions for normalizing OCR coordinates
                let contentRect = try await CoordinateTranslator.getContentRect()

                // Normalize OCR coordinates to 0-1 range
                let nsImage = NSImage(data: imageData)
                let imageWidth = nsImage?.size.width ?? contentRect.width
                let imageHeight = nsImage?.size.height ?? contentRect.height

                var normalizedResults: [[Any]] = []
                for entry in ocrResults {
                    guard entry.count >= 3 else { continue }
                    let text = entry[1]
                    let confidence = entry[2]

                    // Normalize coordinates
                    if let coords = entry[0] as? [[Any]] {
                        var normalizedCoords: [[Double]] = []
                        for point in coords {
                            if let px = point[0] as? Int, let py = point[1] as? Int {
                                normalizedCoords.append([
                                    Double(px) / Double(imageWidth),
                                    Double(py) / Double(imageHeight)
                                ])
                            } else if let px = point[0] as? Double, let py = point[1] as? Double {
                                normalizedCoords.append([
                                    px / Double(imageWidth),
                                    py / Double(imageHeight)
                                ])
                            }
                        }
                        normalizedResults.append([normalizedCoords, text, confidence])
                    }
                }

                let jsonData = try JSONSerialization.data(withJSONObject: normalizedResults)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(
                    content: [.text("iPhone OCR (\(normalizedResults.count) elements, coords normalized 0-1):\n\(jsonString)")],
                    isError: false
                )
            } catch let error as MCPError {
                return error.toResult()
            }

        case "iphone_analyze_screen_now":
            do {
                let imageData = try await captureIPhoneScreen()

                var analysisTypes: [RealtimeAnalyzer.AnalysisType] = []
                if args["include_classification"]?.boolValue ?? true {
                    analysisTypes.append(.classification(topK: 5))
                }
                if args["include_objects"]?.boolValue ?? false {
                    analysisTypes.append(.objectDetection(minConfidence: 0.5))
                }
                if args["include_rectangles"]?.boolValue ?? false {
                    analysisTypes.append(.rectangles(minConfidence: 0.5))
                }
                if args["include_text"]?.boolValue ?? false {
                    analysisTypes.append(.ocr)
                }
                if args["include_saliency"]?.boolValue ?? false {
                    analysisTypes.append(.saliency)
                }

                // Run vision analysis on the cropped iPhone image
                var results: [String: Any] = [:]

                if analysisTypes.contains(where: { $0.name == "classification" }) {
                    let classifications = try await VisionAnalyzer.classifyImage(imageData: imageData, topK: 5)
                    results["classification"] = classifications
                }
                if analysisTypes.contains(where: { $0.name == "objectDetection" }) {
                    let objects = try await VisionAnalyzer.detectObjects(imageData: imageData, minimumConfidence: 0.5)
                    results["objects"] = objects
                }
                if analysisTypes.contains(where: { $0.name == "rectangles" }) {
                    let rectangles = try await VisionAnalyzer.detectRectangles(imageData: imageData, minimumConfidence: 0.5)
                    results["rectangles"] = rectangles
                }
                if analysisTypes.contains(where: { $0.name == "ocr" }) {
                    let ocrResults = try await OCRProcessor.performOCR(on: imageData)
                    results["ocr"] = ocrResults
                }
                if analysisTypes.contains(where: { $0.name == "saliency" }) {
                    let saliency = try await VisionAnalyzer.detectSaliency(imageData: imageData)
                    results["saliency"] = saliency
                }

                let jsonData = try JSONSerialization.data(withJSONObject: results)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                return .init(content: [.text("iPhone screen analysis:\n\(jsonString)")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        case "iphone_analyze_with_llm":
            guard let modelName = args["model_name"]?.stringValue,
                  let instruction = args["instruction"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: model_name and instruction required")], isError: true)
            }
            let maxTokens = args["max_tokens"]?.intValue ?? 512

            do {
                let imageData = try await captureIPhoneScreen()

                // Run OCR and classification on iPhone screen
                let analysisTypes: [RealtimeAnalyzer.AnalysisType] = [
                    .classification(topK: 5),
                    .ocr
                ]

                var screenContent: [String: Any] = [:]
                let classifications = try await VisionAnalyzer.classifyImage(imageData: imageData, topK: 5)
                screenContent["classification"] = classifications
                let ocrResults = try await OCRProcessor.performOCR(on: imageData)
                screenContent["ocr_text"] = ocrResults

                // Pass to LLM
                let llmResult = try await CoreMLManager.shared.analyzeWithLLM(
                    modelName: modelName,
                    screenContent: screenContent,
                    instruction: instruction,
                    maxTokens: maxTokens
                )

                let jsonData = try JSONSerialization.data(withJSONObject: llmResult)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                return .init(content: [.text("iPhone LLM analysis:\n\(jsonString)")], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        // MARK: Convenience
        case "iphone_open_app":
            guard let appName = args["app_name"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: app_name required")], isError: true)
            }
            do {
                let message = try await IOSNavigation.openApp(name: appName)
                return .init(content: [.text(message)], isError: false)
            } catch let error as MCPError {
                return error.toResult()
            }

        case "iphone_wait_for_text":
            guard let searchText = args["text"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: text required")], isError: true)
            }
            let timeoutMs = args["timeout_ms"]?.intValue ?? 5000
            let pollIntervalMs = args["poll_interval_ms"]?.intValue ?? 500
            let startTime = DispatchTime.now()
            let timeoutNanos = UInt64(timeoutMs) * 1_000_000
            let pollNanos = UInt64(pollIntervalMs) * 1_000_000

            while true {
                let elapsed = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
                if elapsed >= timeoutNanos {
                    return .init(content: [.text("Timeout: '\(searchText)' not found on iPhone within \(timeoutMs)ms")], isError: true)
                }
                do {
                    let imageData = try await captureIPhoneScreen()
                    let ocrResults = try await OCRProcessor.performOCR(on: imageData)
                    let nsImg = NSImage(data: imageData)
                    let imgW = nsImg?.size.width ?? 1
                    let imgH = nsImg?.size.height ?? 1

                    for entry in ocrResults {
                        guard entry.count >= 3, let text = entry[1] as? String else { continue }
                        if text.localizedCaseInsensitiveContains(searchText) {
                            var cx = 0.5, cy = 0.5
                            if let coords = entry[0] as? [[Any]], coords.count >= 4 {
                                var sx = 0.0, sy = 0.0
                                for p in coords {
                                    if let px = p[0] as? Int, let py = p[1] as? Int { sx += Double(px); sy += Double(py) }
                                    else if let px = p[0] as? Double, let py = p[1] as? Double { sx += px; sy += py }
                                }
                                cx = sx / Double(coords.count) / Double(imgW)
                                cy = sy / Double(coords.count) / Double(imgH)
                            }
                            let info: [String: Any] = ["found": true, "text": text, "x": cx, "y": cy, "confidence": entry[2], "elapsed_ms": Int(elapsed / 1_000_000)]
                            let jsonData = try JSONSerialization.data(withJSONObject: info)
                            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                            return .init(content: [.text("Text found on iPhone:\n\(jsonString)")], isError: false)
                        }
                    }
                } catch { /* OCR failed this poll, continue */ }
                try await Task.sleep(nanoseconds: pollNanos)
            }

        case "iphone_reconnect":
            let timeoutMs = args["timeout_ms"]?.intValue ?? 30000
            let startTime = DispatchTime.now()
            let timeoutNanos = UInt64(timeoutMs) * 1_000_000

            while true {
                let elapsed = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
                if elapsed >= timeoutNanos {
                    return .init(content: [.text("Timeout: iPhone Mirroring did not reconnect within \(timeoutMs)ms")], isError: true)
                }
                MirroringWindowDetector.clearCache()
                if let (windowID, bounds) = try? MirroringWindowDetector.findMirroringWindow(),
                   MirroringWindowDetector.isConnected() {
                    CoordinateTranslator.clearCache()
                    return .init(content: [.text("iPhone Mirroring reconnected (window \(windowID), \(Int(bounds.width))x\(Int(bounds.height)))")], isError: false)
                }
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }

        default:
            return nil
        }
    }

    // MARK: - Private Helpers

    /// Capture the iPhone screen content area (cropped to content rect).
    private static func captureIPhoneScreen() async throws -> Data {
        let (windowID, windowBounds) = try MirroringWindowDetector.findMirroringWindow()
        let contentRect = try await CoordinateTranslator.getContentRect()

        // Capture the full mirroring window
        guard let fullImage = CGWindowListCreateImage(
            windowBounds,
            .optionIncludingWindow,
            windowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            throw MCPError.mirroringNotRunning
        }

        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0

        // Calculate crop rect in image pixel coordinates
        let cropX = (contentRect.minX - windowBounds.minX) * scaleFactor
        let cropY = (contentRect.minY - windowBounds.minY) * scaleFactor
        let cropW = contentRect.width * scaleFactor
        let cropH = contentRect.height * scaleFactor
        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)

        // Crop to content area
        guard let croppedImage = fullImage.cropping(to: cropRect) else {
            throw MCPError.calibrationFailed("Failed to crop iPhone screen content")
        }

        // Convert to PNG data
        let nsImage = NSImage(cgImage: croppedImage, size: NSSize(width: croppedImage.width, height: croppedImage.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw MCPError.calibrationFailed("Failed to convert iPhone screenshot to PNG")
        }

        return pngData
    }
}
