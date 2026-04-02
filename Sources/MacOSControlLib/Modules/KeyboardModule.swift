import Foundation
import MCP

public enum KeyboardModule: ToolModule {
    public static var tools: [Tool] {
        [
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
        ]
    }

    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        let args = params.arguments ?? [:]
        switch params.name {
        case "type_text":
            guard let text = args["text"]?.stringValue else {
                return .init(content: [.text("Invalid parameters: text required")], isError: true)
            }
            do {
                try await KeyboardControl.typeText(text: text)
                return .init(content: [.text("Typed: \(text)")], isError: false)
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
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }

        default:
            return nil
        }
    }
}
