import Foundation
import AppKit
import ApplicationServices

public final class AccessibilityTreeBuilder {

    /// Roles for which `AXUIElementCopyActionNames` is invoked. All other roles
    /// skip the action lookup to keep the tree build cheap. Add roles here when
    /// a new interactive widget needs action discovery.
    public static let interactiveRoles: Set<String> = [
        "AXButton",
        "AXMenuItem",
        "AXMenuButton",
        "AXTextField",
        "AXTextArea",
        "AXSlider",
        "AXCheckBox",
        "AXRadioButton",
        "AXPopUpButton",
        "AXComboBox",
        "AXLink",
        "AXIncrementor",
        "AXStepper",
        "AXDisclosureTriangle",
        "AXTabGroup",
        "AXTab"
    ]

    private let bridge: AXApplicationBridge

    public init(bridge: AXApplicationBridge) {
        self.bridge = bridge
    }

    /// Build the tree starting from the given element reference.
    /// Root is depth 0; a child at depth N is included iff `N <= maxDepth`.
    public func build(from root: AXElementReference, maxDepth: Int) -> AXNode {
        buildNode(from: root, currentDepth: 0, maxDepth: maxDepth)
    }

    /// Production entrypoint: build the tree for an application by pid,
    /// optionally targeting a specific window by title substring match.
    /// Throws when the application root cannot be obtained or the named window is missing.
    public func build(forPID pid: pid_t, windowTitle: String?, maxDepth: Int) throws -> AXNode {
        if let windowTitle {
            let windows = try bridge.windows(forPID: pid)
            for window in windows {
                if let title = bridge.attribute(.title, of: window),
                   title.localizedCaseInsensitiveContains(windowTitle) {
                    return build(from: window, maxDepth: maxDepth)
                }
            }
            throw MCPError.windowNotFound("Window titled '\(windowTitle)' not found for pid \(pid)")
        }

        guard let root = bridge.applicationRoot(forPID: pid) else {
            throw MCPError.windowNotFound("Application root unavailable for pid \(pid)")
        }
        return build(from: root, maxDepth: maxDepth)
    }

    // MARK: - Recursion

    private func buildNode(from ref: AXElementReference, currentDepth: Int, maxDepth: Int) -> AXNode {
        var node = AXNode(
            role: ref.role,
            title: ref.title,
            description: ref.description,
            value: bridge.rawValue(of: ref),
            position: bridge.position(of: ref),
            size: bridge.size(of: ref),
            identifier: ref.identifier
        )

        if let role = ref.role, Self.interactiveRoles.contains(role) {
            node.actions = (try? bridge.copyActionNames(ref)) ?? []
        }

        if bridge.isEnabledSupported(ref) {
            node.enabled = bridge.isEnabled(ref)
        }

        if let role = ref.role, Self.interactiveRoles.contains(role) {
            node.settable = bridge.isValueSettable(ref)
        }

        let children = (try? bridge.children(of: ref)) ?? []
        if children.isEmpty {
            return node
        }

        let nextDepth = currentDepth + 1
        if nextDepth > maxDepth {
            node.truncated = true
            node.prunedChildCount = children.count
            return node
        }

        node.children = children.map {
            buildNode(from: $0, currentDepth: nextDepth, maxDepth: maxDepth)
        }
        return node
    }
}
