import Foundation
@testable import MacOSControlLib

struct MockAXUIElement {
    var role: String?
    var title: String?
    var identifier: String?
    var label: String?
    var description: String?
    var pid: pid_t
    var bundleId: String?
    var enabled: Bool
    var value: String?
    var children: [MockAXUIElement]
    var supportedActions: [String]

    init(
        role: String? = nil,
        title: String? = nil,
        identifier: String? = nil,
        label: String? = nil,
        description: String? = nil,
        pid: pid_t = 0,
        bundleId: String? = nil,
        enabled: Bool = true,
        value: String? = nil,
        children: [MockAXUIElement] = [],
        supportedActions: [String] = []
    ) {
        self.role = role
        self.title = title
        self.identifier = identifier
        self.label = label
        self.description = description
        self.pid = pid
        self.bundleId = bundleId
        self.enabled = enabled
        self.value = value
        self.children = children
        self.supportedActions = supportedActions
    }
}
