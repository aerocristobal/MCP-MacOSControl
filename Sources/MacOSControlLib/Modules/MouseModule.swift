import Foundation
import MCP

public enum MouseModule: ToolModule {
    public static var tools: [Tool] {
        [
            Tool(
                name: "click_screen",
                description: "Click at the specified screen coordinates",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "x": ["type": "integer", "description": "X coordinate"],
                        "y": ["type": "integer", "description": "Y coordinate"],
                        "button": ["type": "string", "description": "Mouse button (left, right, middle)", "default": "left"]
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
                name: "double_click",
                description: "Double-click at the specified screen coordinates",
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
                name: "scroll",
                description: "Scroll at the current or specified screen position",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "direction": ["type": "string", "description": "Scroll direction: up, down, left, right"],
                        "amount": ["type": "integer", "description": "Scroll amount in lines", "default": 3],
                        "x": ["type": "integer", "description": "X coordinate (optional, defaults to current position)"],
                        "y": ["type": "integer", "description": "Y coordinate (optional, defaults to current position)"]
                    ],
                    required: ["direction"]
                )
            ),
            Tool(
                name: "list_displays",
                description: "List all connected displays with IDs, resolutions, and positions",
                inputSchema: jsonSchema(type: "object")
            ),
        ]
    }

    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]
        switch params.name {
        case "click_screen":
            guard let x = args["x"]?.intValue,
                  let y = args["y"]?.intValue else {
                return .init(content: [.text("Invalid parameters: x and y coordinates required")], isError: true)
            }
            let button = args["button"]?.stringValue ?? "left"
            do {
                try MouseControl.click(x: x, y: y, button: button)
                return .init(content: [.text("Clicked at (\(x), \(y)) with \(button) button")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "get_screen_size":
            let size = MouseControl.getScreenSize()
            return .init(content: [.text("Screen size: \(size.width)x\(size.height)")], isError: false)

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
                try await MouseControl.dragMouse(fromX: fromX, fromY: fromY, toX: toX, toY: toY, duration: duration)
                return .init(content: [.text("Dragged from (\(fromX), \(fromY)) to (\(toX), \(toY))")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "double_click":
            guard let x = args["x"]?.intValue,
                  let y = args["y"]?.intValue else {
                return .init(content: [.text("Invalid parameters: x and y coordinates required")], isError: true)
            }
            do {
                try MouseControl.doubleClick(x: x, y: y)
                return .init(content: [.text("Double-clicked at (\(x), \(y))")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "scroll":
            guard let direction = args["direction"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: direction required")], isError: true)
            }
            let amount = args["amount"]?.intValue ?? 3
            let x = args["x"]?.intValue
            let y = args["y"]?.intValue
            do {
                try MouseControl.scroll(x: x, y: y, direction: direction, amount: amount)
                return .init(content: [.text("Scrolled \(direction) by \(amount)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        case "list_displays":
            let displays = MouseControl.listDisplays()
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: displays)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                return .init(content: [.text("Connected displays (\(displays.count)):\n\(jsonString)")], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        default:
            return nil
        }
    }
}
