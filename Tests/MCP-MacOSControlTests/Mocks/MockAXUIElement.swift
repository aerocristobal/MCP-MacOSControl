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

    // STORY-015 — extended state attributes. nil = "AX attribute unsupported";
    // a Bool value mirrors what AXUIElementCopyAttributeValue would surface.
    var focused: Bool?
    var selected: Bool?
    var expanded: Bool?
    var isMain: Bool?
    var isMinimized: Bool?
    var isFrontmost: Bool?
    /// Optional explicit frame override; when nil the bridge composes from
    /// position + size.
    var frame: CGRect?

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
        supportedActions: [String] = [],
        focused: Bool? = nil,
        selected: Bool? = nil,
        expanded: Bool? = nil,
        isMain: Bool? = nil,
        isMinimized: Bool? = nil,
        isFrontmost: Bool? = nil,
        frame: CGRect? = nil
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
        self.focused = focused
        self.selected = selected
        self.expanded = expanded
        self.isMain = isMain
        self.isMinimized = isMinimized
        self.isFrontmost = isFrontmost
        self.frame = frame
    }
}
