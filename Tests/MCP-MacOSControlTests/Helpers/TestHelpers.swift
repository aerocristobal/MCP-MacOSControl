import Foundation
import XCTest
import MCP
@testable import MacOSControlLib

// MARK: - Test Utilities

func makeParams(name: String, args: [String: Value] = [:]) -> CallTool.Parameters {
    CallTool.Parameters(name: name, arguments: args.isEmpty ? nil : args)
}

func extractText(from result: CallTool.Result) -> String? {
    for content in result.content {
        if case .text(let text, _, _) = content {
            return text
        }
    }
    return nil
}

func requiredParams(for tool: Tool) -> [String] {
    guard case .object(let schema) = tool.inputSchema,
          case .array(let required) = schema["required"] else { return [] }
    return required.compactMap { value in
        if case .string(let s) = value { return s }
        return nil
    }
}

func propertyNames(for tool: Tool) -> Set<String> {
    guard case .object(let schema) = tool.inputSchema,
          case .object(let props) = schema["properties"] else { return [] }
    return Set(props.keys)
}
