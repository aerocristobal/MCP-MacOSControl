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
                propDict[k] = schemaValue(from: v)
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

/// Recursively convert an `Any` value sourced from a property dictionary into an
/// MCP `Value`. Supports the primitives accepted by JSON Schema plus arrays and
/// nested objects so callers can express `enum: [...]` and `items: {...}` shapes.
private func schemaValue(from raw: Any) -> Value {
    // Bool / Int / Double disambiguation: NSNumber bridging makes `Bool as? Int`
    // succeed on Apple platforms, so dispatch on the runtime type first.
    switch raw {
    case let b as Bool where type(of: raw) == Bool.self: return .bool(b)
    case let i as Int where type(of: raw) == Int.self: return .int(i)
    case let d as Double where type(of: raw) == Double.self: return .double(d)
    case let s as String: return .string(s)
    case let arr as [Any]: return .array(arr.map(schemaValue(from:)))
    case let dict as [String: Any]: return .object(dict.mapValues(schemaValue(from:)))
    default:
        // Fallback for numeric types that don't match the strict checks above
        // (e.g. literal `0.5` typed as Double but presented through NSNumber).
        if let b = raw as? Bool { return .bool(b) }
        if let i = raw as? Int { return .int(i) }
        if let d = raw as? Double { return .double(d) }
        return .null
    }
}
