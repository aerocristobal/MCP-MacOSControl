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
            do {
                try MouseControl.click(x: x, y: y)
                return .init(content: [.text("Clicked at (\(x), \(y))")], isError: false)
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

        default:
            return nil
        }
    }
}
