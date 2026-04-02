import Foundation
import MCP

public protocol ToolModule {
    static var tools: [Tool] { get }
    static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result?
}

public func jsonSchema(
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
