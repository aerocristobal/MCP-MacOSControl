import Foundation
import MCP

@main
struct MacOSControlServer {
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

    // MARK: - Tool Definitions

    static func getToolDefinitions() -> [Tool] {
        return [
            Tool(
                name: "click_screen",
                description: "Click at the specified screen coordinates",
                inputSchema: .object(["x": .int(0), "y": .int(0)])
            ),
            Tool(
                name: "get_screen_size",
                description: "Get the current screen resolution",
                inputSchema: .object([:])
            ),
            Tool(
                name: "type_text",
                description: "Type the specified text at the current cursor position",
                inputSchema: .object(["text": .string("")])
            ),
            Tool(
                name: "move_mouse",
                description: "Move the mouse to the specified screen coordinates",
                inputSchema: .object(["x": .int(0), "y": .int(0)])
            ),
            Tool(
                name: "mouse_down",
                description: "Hold down a mouse button ('left', 'right', 'middle')",
                inputSchema: .object(["button": .string("left")])
            ),
            Tool(
                name: "mouse_up",
                description: "Release a mouse button ('left', 'right', 'middle')",
                inputSchema: .object(["button": .string("left")])
            ),
            Tool(
                name: "drag_mouse",
                description: "Drag the mouse from one position to another",
                inputSchema: .object([
                    "from_x": .int(0),
                    "from_y": .int(0),
                    "to_x": .int(0),
                    "to_y": .int(0),
                    "duration": .double(0.5)
                ])
            ),
            Tool(
                name: "key_down",
                description: "Hold down a specific keyboard key until released",
                inputSchema: .object(["key": .string("")])
            ),
            Tool(
                name: "key_up",
                description: "Release a specific keyboard key",
                inputSchema: .object(["key": .string("")])
            ),
            Tool(
                name: "press_keys",
                description: "Press single keys, sequences, or combinations like [['cmd', 'c']]",
                inputSchema: .object(["keys": .array([])])
            ),
            Tool(
                name: "take_screenshot",
                description: "Get screenshot of entire screen or specific window",
                inputSchema: .object([
                    "title_pattern": .string(""),
                    "use_regex": .bool(false),
                    "threshold": .int(60),
                    "save_to_downloads": .bool(false)
                ])
            ),
            Tool(
                name: "take_screenshot_with_ocr",
                description: "Take screenshot and extract text with OCR, returns list of [coordinates, text, confidence]",
                inputSchema: .object([
                    "title_pattern": .string(""),
                    "use_regex": .bool(false),
                    "threshold": .int(60),
                    "save_to_downloads": .bool(false)
                ])
            ),
            Tool(
                name: "list_windows",
                description: "List all open windows on the system",
                inputSchema: .object([:])
            ),
            Tool(
                name: "activate_window",
                description: "Activate a window (bring it to the foreground) by matching its title",
                inputSchema: .object([
                    "title_pattern": .string(""),
                    "use_regex": .bool(false),
                    "threshold": .int(60)
                ])
            ),
            Tool(
                name: "wait_milliseconds",
                description: "Wait for a specified number of milliseconds",
                inputSchema: .object(["milliseconds": .int(0)])
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

        default:
            return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
        }
    }
}
