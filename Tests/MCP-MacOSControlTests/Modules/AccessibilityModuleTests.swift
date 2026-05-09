import XCTest
import MCP
@testable import MacOSControlLib

final class AccessibilityModuleTests: XCTestCase {
    func testHasExpectedTools() {
        XCTAssertEqual(AccessibilityModule.tools.count, 3)
    }

    func testToolNames() {
        let names = AccessibilityModule.tools.map { $0.name }
        XCTAssertTrue(names.contains("accessibility_tree"))
        XCTAssertTrue(names.contains("click_element"))
        XCTAssertTrue(names.contains("perform_ax_action"))
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
}
