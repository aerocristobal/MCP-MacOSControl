import XCTest
import MCP
@testable import MacOSControlLib

final class AccessibilityModuleTests: XCTestCase {
    func testHasExpectedTools() {
        XCTAssertEqual(AccessibilityModule.tools.count, 4)
    }

    func testToolNames() {
        let names = AccessibilityModule.tools.map { $0.name }
        XCTAssertTrue(names.contains("accessibility_tree"))
        XCTAssertTrue(names.contains("click_element"))
        XCTAssertTrue(names.contains("perform_ax_action"))
        XCTAssertTrue(names.contains("element_at_position"))
    }

    func testUnknownToolReturnsNil() async throws {
        let result = try await AccessibilityModule.handle(makeParams(name: "unknown"))
        XCTAssertNil(result)
    }

    // MARK: - STORY-002: click_element registration

    func testRegistersClickElementTool() {
        let names = AccessibilityModule.tools.map { $0.name }
        XCTAssertTrue(names.contains("click_element"))
    }

    func testClickElementToolHasDestructiveHintTrueAndReadOnlyHintFalse() {
        guard let tool = AccessibilityModule.tools.first(where: { $0.name == "click_element" }) else {
            return XCTFail("click_element tool not registered")
        }
        XCTAssertEqual(tool.annotations.destructiveHint, true,
                       "destructiveHint must be true — clicks can activate Delete/Confirm controls")
        XCTAssertEqual(tool.annotations.readOnlyHint, false,
                       "readOnlyHint must be false — clicks mutate UI state")
    }

    func testClickElementToolInputSchemaAcceptsKnownLocators() {
        guard let tool = AccessibilityModule.tools.first(where: { $0.name == "click_element" }) else {
            return XCTFail("click_element tool not registered")
        }
        let props = propertyNames(for: tool)
        for expected in ["role", "title", "identifier", "label", "application", "return_state"] {
            XCTAssertTrue(props.contains(expected), "click_element schema missing property '\(expected)'")
        }
    }

    func testClickElementTool_rejectsCallWithNoLocators() async throws {
        let result = try await AccessibilityModule.handle(
            makeParams(name: "click_element", args: [:])
        )
        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.lowercased().contains("locator"),
                      "expected validation message about missing locator; got: \(text)")
    }

    // MARK: - STORY-003: perform_ax_action registration

    func testRegistersPerformAXActionTool() {
        let names = AccessibilityModule.tools.map { $0.name }
        XCTAssertTrue(names.contains("perform_ax_action"))
    }

    func testPerformAXActionToolHasDestructiveHintTrueAndReadOnlyHintFalse() {
        guard let tool = AccessibilityModule.tools.first(where: { $0.name == "perform_ax_action" }) else {
            return XCTFail("perform_ax_action tool not registered")
        }
        XCTAssertEqual(tool.annotations.destructiveHint, true,
                       "destructiveHint must be true — tool dispatches AXCancel/AXConfirm and arbitrary custom actions")
        XCTAssertEqual(tool.annotations.readOnlyHint, false,
                       "readOnlyHint must be false — actions mutate UI state")
    }

    func testPerformAXActionToolInputSchemaDeclaresExpectedProperties() {
        guard let tool = AccessibilityModule.tools.first(where: { $0.name == "perform_ax_action" }) else {
            return XCTFail("perform_ax_action tool not registered")
        }
        let props = propertyNames(for: tool)
        for expected in ["role", "title", "identifier", "label", "description",
                         "application", "action", "allow_custom"] {
            XCTAssertTrue(props.contains(expected),
                          "perform_ax_action schema missing property '\(expected)'")
        }
    }

    func testPerformAXActionTool_rejectsCallWithNoLocators() async throws {
        let result = try await AccessibilityModule.handle(
            makeParams(name: "perform_ax_action", args: [
                "action": .string("AXPress")
            ])
        )
        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.lowercased().contains("locator"),
                      "expected validation message about missing locator; got: \(text)")
    }

    // MARK: - STORY-004: accessibility_tree v2

    func testAccessibilityTree_inputSchema_keepsExistingParameters() {
        guard let tool = AccessibilityModule.tools.first(where: { $0.name == "accessibility_tree" }) else {
            return XCTFail("accessibility_tree tool not registered")
        }
        let props = propertyNames(for: tool)
        XCTAssertTrue(props.contains("app_name"), "must keep pre-existing app_name parameter")
        XCTAssertTrue(props.contains("window_title"), "must keep pre-existing window_title parameter")
        XCTAssertTrue(props.contains("max_depth"), "must keep pre-existing max_depth parameter")
    }

    func testAccessibilityTree_hasReadOnlyHintTrueAndDestructiveHintFalse() {
        guard let tool = AccessibilityModule.tools.first(where: { $0.name == "accessibility_tree" }) else {
            return XCTFail("accessibility_tree tool not registered")
        }
        XCTAssertEqual(tool.annotations.readOnlyHint, true,
                       "readOnlyHint must be true — tree reads do not modify state")
        XCTAssertEqual(tool.annotations.destructiveHint, false,
                       "destructiveHint must be false — tree reads do not modify state")
    }

    func testAccessibilityTree_descriptionDocumentsNewFields() {
        guard let tool = AccessibilityModule.tools.first(where: { $0.name == "accessibility_tree" }) else {
            return XCTFail("accessibility_tree tool not registered")
        }
        let desc = tool.description ?? ""
        XCTAssertTrue(desc.contains("actions"), "description should mention actions field")
        XCTAssertTrue(desc.contains("enabled"), "description should mention enabled field")
        XCTAssertTrue(desc.contains("settable"), "description should mention settable field")
        XCTAssertTrue(desc.contains("truncated"), "description should mention truncated field")
        XCTAssertTrue(desc.contains("schema_version"), "description should mention schema_version contract")
    }

    func testAccessibilityTree_maxDepthDefaultIs6() {
        guard let tool = AccessibilityModule.tools.first(where: { $0.name == "accessibility_tree" }),
              case .object(let schema) = tool.inputSchema,
              case .object(let props) = schema["properties"],
              case .object(let maxDepth) = props["max_depth"],
              case .int(let defaultValue) = maxDepth["default"] else {
            return XCTFail("accessibility_tree max_depth default not present in schema")
        }
        XCTAssertEqual(defaultValue, 6, "max_depth default should be 6 per resolved Open Question 3")
    }

    // MARK: - STORY-005: element_at_position

    func test_registersElementAtPositionTool() {
        let names = AccessibilityModule.tools.map { $0.name }
        XCTAssertTrue(names.contains("element_at_position"))
    }

    func test_elementAtPositionTool_inputSchema() {
        guard let tool = AccessibilityModule.tools.first(where: { $0.name == "element_at_position" }) else {
            return XCTFail("element_at_position tool not registered")
        }
        let props = propertyNames(for: tool)
        XCTAssertTrue(props.contains("x"))
        XCTAssertTrue(props.contains("y"))
        XCTAssertTrue(props.contains("display_index"))

        let required = Set(requiredParams(for: tool))
        XCTAssertTrue(required.contains("x"))
        XCTAssertTrue(required.contains("y"))
        XCTAssertFalse(required.contains("display_index"),
                       "display_index must be optional")
    }

    func test_elementAtPositionTool_readOnlyHintTrueDestructiveHintFalse() {
        guard let tool = AccessibilityModule.tools.first(where: { $0.name == "element_at_position" }) else {
            return XCTFail("element_at_position tool not registered")
        }
        XCTAssertEqual(tool.annotations.readOnlyHint, true,
                       "readOnlyHint must be true — hit-test does not modify UI state")
        XCTAssertEqual(tool.annotations.destructiveHint, false,
                       "destructiveHint must be false — hit-test is read-only")
    }

    func test_elementAtPositionTool_descriptionEmbedsCoordinateSpaceExample() {
        guard let tool = AccessibilityModule.tools.first(where: { $0.name == "element_at_position" }) else {
            return XCTFail("element_at_position tool not registered")
        }
        let desc = tool.description ?? ""
        XCTAssertTrue(desc.contains("1920"), "description must spell out the coordinate-space example; got: \(desc)")
        XCTAssertTrue(desc.contains("logical points"), "description must clarify logical points vs device pixels; got: \(desc)")
        XCTAssertTrue(desc.contains("top-left"), "description must clarify origin; got: \(desc)")
    }
}
