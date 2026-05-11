import Foundation
import CoreGraphics

public final class AXNodeSerializer {
    public static let schemaVersion = 3

    public init() {}

    /// Serialize a single node (and its children recursively) to a JSON-compatible dictionary.
    public func serialize(_ node: AXNode) -> [String: Any] {
        var dict: [String: Any] = [:]

        if let role = node.role { dict["role"] = role }
        if let title = node.title, !title.isEmpty { dict["title"] = title }
        if let description = node.description, !description.isEmpty { dict["description"] = description }

        if let value = node.value {
            switch value {
            case .string(let s): dict["value"] = s
            case .number(let n): dict["value"] = n
            }
        }

        if let position = node.position {
            dict["position"] = ["x": Int(position.x), "y": Int(position.y)]
        }
        if let size = node.size {
            dict["size"] = ["width": Int(size.width), "height": Int(size.height)]
        }

        if let identifier = node.identifier, !identifier.isEmpty {
            dict["identifier"] = identifier
        }

        if !node.actions.isEmpty {
            dict["actions"] = node.actions
        }

        if let enabled = node.enabled {
            dict["enabled"] = enabled
        }

        if let settable = node.settable {
            dict["settable"] = settable
        }

        if let truncated = node.truncated {
            dict["truncated"] = truncated
        }

        if let focused = node.focused {
            dict["focused"] = focused
        }

        if let selected = node.selected {
            dict["selected"] = selected
        }

        if let expanded = node.expanded {
            dict["expanded"] = expanded
        }

        if let visibleInViewport = node.visibleInViewport {
            dict["visible_in_viewport"] = visibleInViewport
        }

        if let isMain = node.isMain {
            dict["is_main"] = isMain
        }

        if let isMinimized = node.isMinimized {
            dict["is_minimized"] = isMinimized
        }

        if let isFrontmost = node.isFrontmost {
            dict["is_frontmost"] = isFrontmost
        }

        if !node.children.isEmpty {
            dict["children"] = node.children.map { serialize($0) }
        }

        if let count = node.prunedChildCount {
            dict["childCount"] = count
        }

        return dict
    }

    /// Serialize the root node and add the top-level `schema_version` field.
    /// Other root fields remain at the top level (no envelope wrapper) for
    /// backward compatibility with v1 callers that read response["role"] etc.
    public func serializeRoot(_ node: AXNode) -> [String: Any] {
        var dict = serialize(node)
        dict["schema_version"] = Self.schemaVersion
        return dict
    }
}
