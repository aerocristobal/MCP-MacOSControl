// STORY: STORY-015 — Extended Element State Attributes
// COMPONENT: AXNodeSerializer (state-field extension)

import XCTest
@testable import MacOSControlLib

final class AXNodeSerializer_StateTests: XCTestCase {

    var serializer: AXNodeSerializer!

    override func setUp() {
        super.setUp()
        serializer = AXNodeSerializer()
    }

    // MARK: - Schema Version Bump (Scenario 7)

    func test_schemaVersion_isIncrementedTo3() {
        XCTAssertEqual(AXNodeSerializer.schemaVersion, 3)
    }

    func test_serializeRoot_includesSchemaVersion3_atRoot() {
        let dict = serializer.serializeRoot(AXNode(role: "AXApplication"))
        XCTAssertEqual(dict["schema_version"] as? Int, 3)
    }

    // MARK: - Focused (Scenario 1)

    func test_serialize_focusedTrue_whenAXFocusedIsTrue() {
        let node = AXNode(role: "AXTextField", focused: true)
        let dict = serializer.serialize(node)
        XCTAssertEqual(dict["focused"] as? Bool, true)
    }

    func test_serialize_omitsFocused_whenAttributeUnsupported() {
        let node = AXNode(role: "AXTextField", focused: nil)
        let dict = serializer.serialize(node)
        XCTAssertNil(dict["focused"], "focused must be omitted, not serialized as false, when AXFocused is unsupported")
    }

    // MARK: - Selected (Scenario 2 + Open Q3 role gating)

    func test_serialize_selected_forAXRow() {
        let node = AXNode(role: "AXRow", selected: true)
        let dict = serializer.serialize(node)
        XCTAssertEqual(dict["selected"] as? Bool, true)
    }

    func test_serialize_omitsSelected_forNonSelectableRole() {
        let node = AXNode(role: "AXButton", selected: nil)
        let dict = serializer.serialize(node)
        XCTAssertNil(dict["selected"])
    }

    // MARK: - Expanded (Scenario 3)

    func test_serialize_expanded_forAXDisclosureTriangle() {
        let node = AXNode(role: "AXDisclosureTriangle", expanded: true)
        let dict = serializer.serialize(node)
        XCTAssertEqual(dict["expanded"] as? Bool, true)
    }

    func test_serialize_expanded_falseForCollapsedDisclosure() {
        let node = AXNode(role: "AXDisclosureTriangle", expanded: false)
        let dict = serializer.serialize(node)
        XCTAssertEqual(dict["expanded"] as? Bool, false)
    }

    // MARK: - Visible in viewport (Scenario 4)

    func test_serialize_visibleInViewportTrue_whenSet() {
        let node = AXNode(role: "AXRow", visibleInViewport: true)
        let dict = serializer.serialize(node)
        XCTAssertEqual(dict["visible_in_viewport"] as? Bool, true)
    }

    func test_serialize_visibleInViewportFalse_whenSet() {
        let node = AXNode(role: "AXRow", visibleInViewport: false)
        let dict = serializer.serialize(node)
        XCTAssertEqual(dict["visible_in_viewport"] as? Bool, false)
    }

    func test_serialize_omitsVisibleInViewport_whenNil() {
        let node = AXNode(role: "AXRow", visibleInViewport: nil)
        let dict = serializer.serialize(node)
        XCTAssertNil(dict["visible_in_viewport"])
    }

    // MARK: - Window State (Scenario 5)

    func test_serialize_windowStateFields_forAXWindowRole() {
        let node = AXNode(role: "AXWindow", isMain: false, isMinimized: false, isFrontmost: true)
        let dict = serializer.serialize(node)
        XCTAssertEqual(dict["is_frontmost"] as? Bool, true)
        XCTAssertEqual(dict["is_minimized"] as? Bool, false)
        XCTAssertEqual(dict["is_main"] as? Bool, false)
    }

    func test_serialize_skipsWindowStateFields_forNonWindowRoles() {
        let node = AXNode(role: "AXButton", isMain: nil, isMinimized: nil, isFrontmost: nil)
        let dict = serializer.serialize(node)
        XCTAssertNil(dict["is_frontmost"])
        XCTAssertNil(dict["is_minimized"])
        XCTAssertNil(dict["is_main"])
    }

    // MARK: - Backward Compat (Scenario 7)

    func test_serialize_preservesAllV2Fields_whenStateFieldsAdded() {
        let node = AXNode(
            role: "AXButton",
            title: "Save",
            identifier: "save-button",
            actions: ["AXPress"],
            enabled: true,
            settable: false,
            focused: true
        )
        let dict = serializer.serialize(node)
        XCTAssertEqual(dict["role"] as? String, "AXButton")
        XCTAssertEqual(dict["title"] as? String, "Save")
        XCTAssertEqual(dict["identifier"] as? String, "save-button")
        XCTAssertEqual(dict["actions"] as? [String], ["AXPress"])
        XCTAssertEqual(dict["enabled"] as? Bool, true)
        XCTAssertEqual(dict["settable"] as? Bool, false)
        XCTAssertEqual(dict["focused"] as? Bool, true)
    }
}
