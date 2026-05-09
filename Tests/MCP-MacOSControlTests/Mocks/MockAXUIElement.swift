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
    var children: [MockAXUIElement]

    init(
        role: String? = nil,
        title: String? = nil,
        identifier: String? = nil,
        label: String? = nil,
        description: String? = nil,
        pid: pid_t = 0,
        bundleId: String? = nil,
        children: [MockAXUIElement] = []
    ) {
        self.role = role
        self.title = title
        self.identifier = identifier
        self.label = label
        self.description = description
        self.pid = pid
        self.bundleId = bundleId
        self.children = children
    }
}
