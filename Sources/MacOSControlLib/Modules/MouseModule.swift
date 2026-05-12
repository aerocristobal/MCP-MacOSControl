import Foundation
import MCP

public enum MouseModule: ToolModule {
    public static var tools: [Tool] {
        [
            Tool(
                name: "click_screen",
                description: "Click at absolute screen coordinates with the chosen mouse button. Use when you need pixel-based input and AX semantic targeting is unavailable. DESTRUCTIVE: can activate Delete / Send / Confirm controls — prefer accessibility_tree + click_element when the target has an AX identity. Returns a confirmation string naming the actual coordinates and button used.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "x": ["type": "integer", "description": "Global X coordinate in logical points, top-left origin across the union of attached displays."],
                        "y": ["type": "integer", "description": "Global Y coordinate in logical points, top-left origin across the union of attached displays."],
                        "button": [
                            "type": "string",
                            "description": "Mouse button: one of left, right, or middle. Defaults to \"left\" when omitted.",
                            "enum": ["left", "right", "middle"],
                            "default": "left"
                        ]
                    ],
                    required: ["x", "y"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: true,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "get_screen_size",
                description: "Return the main display's logical-point resolution as \"WxH\". Use this to validate coordinates before invoking click_screen / move_mouse / drag_mouse. Read-only; does not modify any system state and is safe to retry.",
                inputSchema: jsonSchema(type: "object"),
                annotations: Tool.Annotations(
                    readOnlyHint: true,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "move_mouse",
                description: "Move the cursor to absolute screen coordinates without clicking. Use to hover or pre-position before invoking click_screen. Idempotent — calling twice with the same (x, y) ends at the same point. Returns a confirmation string with the destination coordinates.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "x": ["type": "integer", "description": "Global X coordinate in logical points."],
                        "y": ["type": "integer", "description": "Global Y coordinate in logical points."]
                    ],
                    required: ["x", "y"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: false,
                    idempotentHint: true
                )
            ),
            Tool(
                name: "mouse_down",
                description: "Press and hold a mouse button without releasing it. Use to start a manual drag or to coordinate with mouse_up for custom gestures. DESTRUCTIVE: a held button release elsewhere may activate Delete / Confirm controls. Returns a confirmation string naming the held button.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "button": [
                            "type": "string",
                            "description": "Mouse button to press and hold: one of left, right, or middle. Defaults to \"left\" when omitted.",
                            "enum": ["left", "right", "middle"],
                            "default": "left"
                        ]
                    ]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: true,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "mouse_up",
                description: "Release a previously-held mouse button. Use to finish a manual drag started by mouse_down. DESTRUCTIVE: the release point determines which UI control receives the click and may activate Delete / Confirm. Returns a confirmation string.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "button": [
                            "type": "string",
                            "description": "Mouse button to release: one of left, right, or middle. Defaults to \"left\" when omitted.",
                            "enum": ["left", "right", "middle"],
                            "default": "left"
                        ]
                    ]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: true,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "drag_mouse",
                description: "Drag the cursor from one screen coordinate to another with a smooth interpolated path. Use for selection, reordering, and gesture-driven controls. DESTRUCTIVE: the drop point may activate any UI control under it (delete, move file, dismiss). Returns a confirmation string naming the path endpoints.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "from_x": ["type": "integer", "description": "Drag start X coordinate (global logical points)."],
                        "from_y": ["type": "integer", "description": "Drag start Y coordinate (global logical points)."],
                        "to_x": ["type": "integer", "description": "Drag end X coordinate (global logical points)."],
                        "to_y": ["type": "integer", "description": "Drag end Y coordinate (global logical points)."],
                        "duration": ["type": "number", "description": "Drag duration in seconds (default 0.5).", "default": 0.5]
                    ],
                    required: ["from_x", "from_y", "to_x", "to_y"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: true,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "double_click",
                description: "Perform a double-click at absolute screen coordinates. Use to open items in Finder, enter rename mode on icons, or activate double-click-only controls. DESTRUCTIVE: can launch applications and open files. Returns a confirmation string with the coordinates.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "x": ["type": "integer", "description": "Global X coordinate in logical points."],
                        "y": ["type": "integer", "description": "Global Y coordinate in logical points."]
                    ],
                    required: ["x", "y"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: true,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "scroll",
                description: "Scroll the scrollable area under the cursor by a line-count in the given direction. Use to bring content into view before clicking. Coordinates are optional — when omitted the current cursor position is used. Returns a confirmation string naming the direction and amount.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "direction": [
                            "type": "string",
                            "description": "Scroll direction: one of up, down, left, or right.",
                            "enum": ["up", "down", "left", "right"]
                        ],
                        "amount": ["type": "integer", "description": "Number of lines to scroll. Defaults to 3.", "default": 3],
                        "x": ["type": "integer", "description": "Optional X coordinate; defaults to current cursor position."],
                        "y": ["type": "integer", "description": "Optional Y coordinate; defaults to current cursor position."]
                    ],
                    required: ["direction"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "list_displays",
                description: "Enumerate every attached display with its ID, resolution, and frame origin in the global coordinate space. Use to translate display-local coordinates into the global space expected by click_screen / move_mouse. Read-only; returns a JSON array.",
                inputSchema: jsonSchema(type: "object"),
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
