import Foundation
import CoreGraphics

public enum AXNodeValue: Sendable, Equatable {
    case string(String)
    case number(NSNumber)

    public static func == (lhs: AXNodeValue, rhs: AXNodeValue) -> Bool {
        switch (lhs, rhs) {
        case let (.string(a), .string(b)): return a == b
        case let (.number(a), .number(b)): return a == b
        default: return false
        }
    }
}

public struct AXNode {
    public var role: String?
    public var title: String?
    public var description: String?
    public var value: AXNodeValue?
    public var position: CGPoint?
    public var size: CGSize?
    public var identifier: String?
    public var actions: [String]
    public var enabled: Bool?
    public var settable: Bool?
    public var truncated: Bool?
    public var children: [AXNode]
    public var prunedChildCount: Int?

    public init(
        role: String? = nil,
        title: String? = nil,
        description: String? = nil,
        value: AXNodeValue? = nil,
        position: CGPoint? = nil,
        size: CGSize? = nil,
        identifier: String? = nil,
        actions: [String] = [],
        enabled: Bool? = nil,
        settable: Bool? = nil,
        truncated: Bool? = nil,
        children: [AXNode] = [],
        prunedChildCount: Int? = nil
    ) {
        self.role = role
        self.title = title
        self.description = description
        self.value = value
        self.position = position
        self.size = size
        self.identifier = identifier
        self.actions = actions
        self.enabled = enabled
        self.settable = settable
        self.truncated = truncated
        self.children = children
        self.prunedChildCount = prunedChildCount
    }

    public func collectRoles() -> [String] {
        var roles: [String] = []
        if let role { roles.append(role) }
        for child in children {
            roles.append(contentsOf: child.collectRoles())
        }
        return roles
    }
}
