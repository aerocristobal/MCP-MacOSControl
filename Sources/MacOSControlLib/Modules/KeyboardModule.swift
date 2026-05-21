import Foundation
import MCP

public enum KeyboardModule: ToolModule {
    public static var tools: [Tool] {
        [
            Tool(
                name: "type_text",
                description: "Type a Unicode string at the current keyboard focus, one character at a time. Use to fill text fields or compose messages after focusing the field. Sends raw characters — destructive shortcuts must be sent through press_keys. Returns a confirmation string echoing what was typed.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "text": ["type": "string", "description": "Text to type at the current focus. Supports Unicode and multi-line via embedded newlines."]
                    ],
                    required: ["text"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "key_down",
                description: "Press and hold a single keyboard key without releasing it. Use to start chord sequences when paired with key_up, or to assert modifier state across multiple actions. Returns a confirmation string naming the held key.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "key": ["type": "string", "description": "Key name to hold down (e.g. \"a\", \"cmd\", \"shift\", \"return\")."]
                    ],
                    required: ["key"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "key_up",
                description: "Release a previously-held keyboard key. Use to finish a chord sequence started by key_down. Returns a confirmation string naming the released key.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "key": ["type": "string", "description": "Key name to release (must match the key passed to key_down)."]
                    ],
                    required: ["key"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
            Tool(
                name: "press_keys",
                description: "Press one or more key combinations as atomic events. Each entry can be a single key like \"return\" or an array forming a chord like [\"cmd\", \"c\"]. Modifier names: cmd, shift, ctrl, alt (alias option), fn. Use for shortcuts and command-key sequences. Returns a confirmation string.",
                inputSchema: jsonSchema(
                    type: "object",
                    properties: [
                        "keys": ["type": "array", "description": "Array of key entries. Each entry is either a single key string (\"return\") or a chord array ([\"cmd\", \"c\"]). Modifier vocabulary: cmd, shift, ctrl, alt/option, fn."]
                    ],
                    required: ["keys"]
                ),
                annotations: Tool.Annotations(
                    readOnlyHint: false,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
        ]
    }

    public static func handle(_ params: CallTool.Parameters, context: ToolCallContext) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]
        switch params.name {
        case "type_text":
            guard let text = args["text"]?.stringValue else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "text required")
            }
            do {
                try await KeyboardControl.typeText(text: text)
                return .init(content: [.text("Typed: \(text)")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "key_down":
            guard let key = args["key"]?.stringValue else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "key required")
            }
            do {
                try KeyboardControl.keyDown(key: key)
                return .init(content: [.text("Key \(key) down")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "key_up":
            guard let key = args["key"]?.stringValue else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "key required")
            }
            do {
                try KeyboardControl.keyUp(key: key)
                return .init(content: [.text("Key \(key) up")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        case "press_keys":
            guard let keysValue = args["keys"]?.arrayValue else {
                return MCPErrorResponseBuilder.shared.build(code: "invalid_input", message: "keys array required")
            }
            let keys = keysValue.map { value -> Any in
                if let str = value.stringValue {
                    return str
                } else if let arr = value.arrayValue {
                    return arr.compactMap { $0.stringValue }
                }
                return value
            }
            do {
                try await KeyboardControl.pressKeys(keys: keys)
                return .init(content: [.text("Pressed keys")], isError: false)
            } catch {
                return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
            }

        default:
            return nil
        }
    }
}
