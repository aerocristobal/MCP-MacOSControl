import Foundation
import ApplicationServices

public enum AXAttributeKind: String, CaseIterable, Sendable {
    case role
    case title
    case identifier
    case label
    case description
}

public enum AXResolverScope: Sendable {
    case pid(pid_t)
    case bundleId(String)
    case name(String)
}

enum AXElementHandle {
    case real(AXUIElement)
    case mock(UUID)
}

public struct AXElementReference {
    public let role: String?
    public let title: String?
    public let identifier: String?
    public let label: String?
    public let description: String?
    public let pid: pid_t?
    public let bundleId: String?
    let handle: AXElementHandle

    init(
        role: String? = nil,
        title: String? = nil,
        identifier: String? = nil,
        label: String? = nil,
        description: String? = nil,
        pid: pid_t? = nil,
        bundleId: String? = nil,
        handle: AXElementHandle
    ) {
        self.role = role
        self.title = title
        self.identifier = identifier
        self.label = label
        self.description = description
        self.pid = pid
        self.bundleId = bundleId
        self.handle = handle
    }
}

public struct AXResolverOptions: Sendable {
    public var maxDepth: Int
    public var timeout: TimeInterval

    public init(maxDepth: Int = 10, timeout: TimeInterval = 2.0) {
        self.maxDepth = maxDepth
        self.timeout = timeout
    }
}
