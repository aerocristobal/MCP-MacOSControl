import Foundation
import CoreGraphics
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
    var enabledSupported: Bool
    var value: String?
    var rawValue: AXNodeValue?
    var position: CGPoint?
    var size: CGSize?
    var valueSettable: Bool
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
        enabledSupported: Bool = true,
        value: String? = nil,
        rawValue: AXNodeValue? = nil,
        position: CGPoint? = nil,
        size: CGSize? = nil,
        valueSettable: Bool = false,
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
        self.enabledSupported = enabledSupported
        self.value = value
        self.rawValue = rawValue
        self.position = position
        self.size = size
        self.valueSettable = valueSettable
        self.children = children
        self.supportedActions = supportedActions
    }
}
