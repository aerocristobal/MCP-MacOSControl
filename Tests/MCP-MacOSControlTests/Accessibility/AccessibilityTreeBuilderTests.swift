// STORY: STORY-004 — Enhanced Accessibility Tree Tool
// COMPONENT: AccessibilityTreeBuilder

import XCTest
import CoreGraphics
@testable import MacOSControlLib

final class AccessibilityTreeBuilderTests: XCTestCase {

    var bridge: MockAXApplicationBridge!
    var builder: AccessibilityTreeBuilder!

    override func setUp() {
        super.setUp()
        bridge = MockAXApplicationBridge(elements: [])
        builder = AccessibilityTreeBuilder(bridge: bridge)
    }

    private func rootRef(_ mock: MockAXUIElement, pid: pid_t = 1) -> AXElementReference {
        var m = mock
        m.pid = pid
        bridge.applicationRoots[pid] = m
        return bridge.applicationRoot(forPID: pid)!
    }

    // MARK: - Action Names (Scenario 1)

    func test_build_includesAXActionNames_forInteractiveNodes() {
        let button = MockAXUIElement(role: "AXButton", title: "Bold", supportedActions: ["AXPress"])
        let root = rootRef(button)

        let tree = builder.build(from: root, maxDepth: 5)

        XCTAssertEqual(tree.role, "AXButton")
        XCTAssertEqual(tree.title, "Bold")
        XCTAssertEqual(tree.actions, ["AXPress"])
    }

    func test_build_skipsActionLookup_forKnownNonInteractiveRoles() {
        let staticText = MockAXUIElement(role: "AXStaticText", title: "Version 1.0")
        let root = rootRef(staticText)

        _ = builder.build(from: root, maxDepth: 5)

        XCTAssertEqual(bridge.copyActionNamesCallCount, 0,
                       "non-interactive roles must not trigger action lookup")
    }

    func test_build_callsActionLookup_onlyForInteractiveRoles_inMixedTree() {
        let button = MockAXUIElement(role: "AXButton", title: "OK", supportedActions: ["AXPress"])
        let label = MockAXUIElement(role: "AXStaticText", title: "Hello")
        let group = MockAXUIElement(role: "AXGroup", children: [button, label])
        let window = MockAXUIElement(role: "AXWindow", children: [group])
        let root = rootRef(window)

        _ = builder.build(from: root, maxDepth: 10)

        // One call: only the AXButton. Window/Group/StaticText are non-interactive.
        XCTAssertEqual(bridge.copyActionNamesCallCount, 1)
    }

    // MARK: - Identifier (Scenario 3)

    func test_build_propagatesIdentifierFromReference() {
        let element = MockAXUIElement(role: "AXButton", title: "Save", identifier: "save-btn")
        let root = rootRef(element)

        let tree = builder.build(from: root, maxDepth: 1)

        XCTAssertEqual(tree.identifier, "save-btn")
    }

    // MARK: - Enabled (Scenario 2)

    func test_build_setsEnabledFalse_forDisabledElements() {
        let menuItem = MockAXUIElement(role: "AXMenuItem", title: "Cut", enabled: false)
        let root = rootRef(menuItem)

        let tree = builder.build(from: root, maxDepth: 1)

        XCTAssertEqual(tree.enabled, false)
    }

    func test_build_omitsEnabled_whenAttributeUnsupported() {
        let group = MockAXUIElement(role: "AXGroup", enabledSupported: false)
        let root = rootRef(group)

        let tree = builder.build(from: root, maxDepth: 1)

        XCTAssertNil(tree.enabled, "AXGroup containers without AXEnabled should not surface a value")
    }

    // MARK: - Settable (Scenario 4)

    func test_build_setsSettableTrue_forTextFieldWithSettableValue() {
        let field = MockAXUIElement(role: "AXTextField", title: "Username", valueSettable: true)
        let root = rootRef(field)

        let tree = builder.build(from: root, maxDepth: 1)

        XCTAssertEqual(tree.settable, true)
    }

    func test_build_setsSettableTrue_forSlider() {
        let slider = MockAXUIElement(role: "AXSlider", title: "Volume", valueSettable: true)
        let root = rootRef(slider)

        let tree = builder.build(from: root, maxDepth: 1)

        XCTAssertEqual(tree.settable, true)
    }

    // MARK: - Depth Limiting (Scenario 5)

    func test_build_prunesNodes_beyondMaxDepth() {
        let leaf = MockAXUIElement(role: "AXButton", title: "Leaf")
        let l3 = MockAXUIElement(role: "AXGroup", children: [leaf])
        let l2 = MockAXUIElement(role: "AXGroup", children: [l3])
        let l1 = MockAXUIElement(role: "AXGroup", children: [l2])
        let window = MockAXUIElement(role: "AXWindow", children: [l1])
        let root = rootRef(window)

        let tree = builder.build(from: root, maxDepth: 2)

        let roles = tree.collectRoles()
        XCTAssertTrue(roles.contains("AXWindow"))
        XCTAssertFalse(roles.contains("AXButton"),
                       "leaf at depth 4 must be pruned at maxDepth 2")
    }

    func test_build_setsTruncatedFlag_onParentWithPrunedChildren() {
        let leaf = MockAXUIElement(role: "AXButton", title: "Leaf")
        let l2 = MockAXUIElement(role: "AXGroup", children: [leaf])
        let window = MockAXUIElement(role: "AXWindow", children: [l2])
        let root = rootRef(window)

        let tree = builder.build(from: root, maxDepth: 1)

        // root at depth 0; l2 at depth 1 included; l2's children at depth 2 pruned.
        let l2Node = tree.children.first
        XCTAssertEqual(l2Node?.role, "AXGroup")
        XCTAssertEqual(l2Node?.truncated, true)
        XCTAssertEqual(l2Node?.prunedChildCount, 1)
    }

    func test_build_noTruncatedFlag_whenTreeFitsWithinMaxDepth() {
        let window = MockAXUIElement(role: "AXWindow", children: [])
        let root = rootRef(window)

        let tree = builder.build(from: root, maxDepth: 5)

        XCTAssertNil(tree.truncated)
    }

    func test_build_noTruncatedFlag_onLeafNodes() {
        let button = MockAXUIElement(role: "AXButton", title: "Solo")
        let root = rootRef(button)

        let tree = builder.build(from: root, maxDepth: 0)

        XCTAssertNil(tree.truncated, "leaf with no children should not be flagged truncated")
    }

    // MARK: - Position / Size

    func test_build_propagatesPositionAndSize() {
        var element = MockAXUIElement(role: "AXButton", title: "OK")
        element.position = CGPoint(x: 100, y: 200)
        element.size = CGSize(width: 80, height: 32)
        let root = rootRef(element)

        let tree = builder.build(from: root, maxDepth: 1)

        XCTAssertEqual(tree.position, CGPoint(x: 100, y: 200))
        XCTAssertEqual(tree.size, CGSize(width: 80, height: 32))
    }

    // MARK: - Value typing

    func test_build_propagatesNumericValue() {
        var slider = MockAXUIElement(role: "AXSlider")
        slider.rawValue = .number(NSNumber(value: 0.5))
        let root = rootRef(slider)

        let tree = builder.build(from: root, maxDepth: 1)

        XCTAssertEqual(tree.value, .number(NSNumber(value: 0.5)))
    }

    func test_build_propagatesStringValue() {
        var field = MockAXUIElement(role: "AXTextField", value: "hello")
        field.rawValue = .string("hello")
        let root = rootRef(field)

        let tree = builder.build(from: root, maxDepth: 1)

        XCTAssertEqual(tree.value, .string("hello"))
    }

    // MARK: - STORY-005: buildShallow

    func test_buildShallow_extractsCoreAttributes() {
        let button = MockAXUIElement(
            role: "AXButton",
            title: "Save",
            identifier: "save-btn",
            description: "Saves the current document",
            position: CGPoint(x: 100, y: 200),
            size: CGSize(width: 80, height: 30),
            supportedActions: ["AXPress"]
        )
        let ref = rootRef(button)

        let node = builder.buildShallow(from: ref)

        XCTAssertEqual(node.role, "AXButton")
        XCTAssertEqual(node.title, "Save")
        XCTAssertEqual(node.identifier, "save-btn")
        XCTAssertEqual(node.description, "Saves the current document")
        XCTAssertEqual(node.position, CGPoint(x: 100, y: 200))
        XCTAssertEqual(node.size, CGSize(width: 80, height: 30))
        XCTAssertEqual(node.actions, ["AXPress"])
    }

    func test_buildShallow_omitsChildren_evenWhenChildrenExist() {
        let child = MockAXUIElement(role: "AXStaticText", title: "label")
        let parent = MockAXUIElement(role: "AXGroup", title: "container", children: [child])
        let ref = rootRef(parent)

        let node = builder.buildShallow(from: ref)

        XCTAssertTrue(node.children.isEmpty,
                      "buildShallow must not recurse into children")
        XCTAssertNil(node.truncated,
                     "buildShallow must not flag the node as truncated — that lies about why children are absent")
        XCTAssertNil(node.prunedChildCount,
                     "buildShallow must not report pruned child count")
    }

    func test_buildShallow_setsSettable_forInteractiveTextField() {
        var textField = MockAXUIElement(role: "AXTextField", title: "Search")
        textField.valueSettable = true
        let ref = rootRef(textField)

        let node = builder.buildShallow(from: ref)

        XCTAssertEqual(node.settable, true)
    }

    func test_buildShallow_setsEnabled_whenSupported() {
        var element = MockAXUIElement(role: "AXButton", title: "OK")
        element.enabled = false
        element.enabledSupported = true
        let ref = rootRef(element)

        let node = builder.buildShallow(from: ref)

        XCTAssertEqual(node.enabled, false)
    }

    // MARK: - STORY-015: Extended state attributes

    func test_build_propagatesFocused_fromBridge() {
        let textField = MockAXUIElement(role: "AXTextField", title: "Search", focused: true)
        let root = rootRef(textField)

        let tree = builder.build(from: root, maxDepth: 1)

        XCTAssertEqual(tree.focused, true)
    }

    func test_build_propagatesSelected_forAXRow() {
        let row = MockAXUIElement(role: "AXRow", selected: true)
        let root = rootRef(row)

        let tree = builder.build(from: root, maxDepth: 1)

        XCTAssertEqual(tree.selected, true)
    }

    func test_build_skipsSelected_forAXButton() {
        // Even if the mock supplies a selected value, the bridge gates by
        // role — non-selectable roles must surface nil so the field is omitted.
        let button = MockAXUIElement(role: "AXButton", title: "Save", selected: true)
        let root = rootRef(button)

        let tree = builder.build(from: root, maxDepth: 1)

        XCTAssertNil(tree.selected,
                     "selected must be nil for AXButton — role-gated lookup")
    }

    func test_build_propagatesExpanded_forDisclosureTriangle() {
        let triangle = MockAXUIElement(role: "AXDisclosureTriangle", expanded: true)
        let root = rootRef(triangle)

        let tree = builder.build(from: root, maxDepth: 1)

        XCTAssertEqual(tree.expanded, true)
    }

    func test_build_setsWindowStateFlags_onAXWindowRoleOnly() {
        let window = MockAXUIElement(
            role: "AXWindow",
            title: "Untitled",
            isMain: true,
            isMinimized: false,
            isFrontmost: true
        )
        let root = rootRef(window)

        let tree = builder.build(from: root, maxDepth: 1)

        XCTAssertEqual(tree.isMain, true)
        XCTAssertEqual(tree.isMinimized, false)
        XCTAssertEqual(tree.isFrontmost, true)
    }

    func test_build_omitsWindowStateFlags_onNonWindowRoles() {
        let button = MockAXUIElement(
            role: "AXButton",
            title: "Save",
            isMain: true,
            isMinimized: true,
            isFrontmost: true
        )
        let root = rootRef(button)

        let tree = builder.build(from: root, maxDepth: 1)

        XCTAssertNil(tree.isMain)
        XCTAssertNil(tree.isMinimized)
        XCTAssertNil(tree.isFrontmost)
    }

    func test_build_setsVisibleInViewport_true_whenChildIntersectsAncestorWindow() {
        var inner = MockAXUIElement(role: "AXButton", title: "OK")
        inner.position = CGPoint(x: 100, y: 100)
        inner.size = CGSize(width: 50, height: 30)
        var window = MockAXUIElement(role: "AXWindow", title: "Untitled", children: [inner])
        window.position = CGPoint(x: 0, y: 0)
        window.size = CGSize(width: 800, height: 600)
        let root = rootRef(window)

        let tree = builder.build(from: root, maxDepth: 5)

        let buttonNode = tree.children.first
        XCTAssertEqual(buttonNode?.role, "AXButton")
        XCTAssertEqual(buttonNode?.visibleInViewport, true)
    }

    func test_build_setsVisibleInViewport_false_whenChildOutsideAncestorWindow() {
        var inner = MockAXUIElement(role: "AXButton", title: "Hidden")
        inner.position = CGPoint(x: 1000, y: 1000)
        inner.size = CGSize(width: 50, height: 30)
        var window = MockAXUIElement(role: "AXWindow", title: "Untitled", children: [inner])
        window.position = CGPoint(x: 0, y: 0)
        window.size = CGSize(width: 800, height: 600)
        let root = rootRef(window)

        let tree = builder.build(from: root, maxDepth: 5)

        let buttonNode = tree.children.first
        XCTAssertEqual(buttonNode?.visibleInViewport, false)
    }

    func test_build_omitsVisibleInViewport_onWindowRootItself() {
        var window = MockAXUIElement(role: "AXWindow", title: "Untitled")
        window.position = CGPoint(x: 0, y: 0)
        window.size = CGSize(width: 800, height: 600)
        let root = rootRef(window)

        let tree = builder.build(from: root, maxDepth: 1)

        XCTAssertNil(tree.visibleInViewport,
                     "the window root has no containing window — viewport flag must be omitted")
    }

    func test_buildShallow_omitsVisibleInViewport() {
        var element = MockAXUIElement(role: "AXButton", title: "OK")
        element.position = CGPoint(x: 100, y: 100)
        element.size = CGSize(width: 50, height: 30)
        let ref = rootRef(element)

        let node = builder.buildShallow(from: ref)

        XCTAssertNil(node.visibleInViewport,
                     "shallow build has no ancestor context — viewport flag is omitted by design")
    }

    func test_buildShallow_setsFocusedSelectedExpanded() {
        let row = MockAXUIElement(
            role: "AXRow",
            focused: true,
            selected: true,
            expanded: false
        )
        let ref = rootRef(row)

        let node = builder.buildShallow(from: ref)

        XCTAssertEqual(node.focused, true)
        XCTAssertEqual(node.selected, true)
        XCTAssertEqual(node.expanded, false)
    }
}
