// STORY-006 — run_applescript MCP Tool
// COMPONENT: AppleScriptModule

import XCTest
import MCP
@testable import MacOSControlLib

final class AppleScriptModuleTests: XCTestCase {

    func test_registersRunAppleScriptTool() {
        let names = AppleScriptModule.tools.map { $0.name }
        XCTAssertTrue(names.contains("run_applescript"))
    }

    func test_runAppleScriptTool_inputSchema_hasExpectedProperties() {
        guard let tool = AppleScriptModule.tools.first(where: { $0.name == "run_applescript" }) else {
            return XCTFail("run_applescript tool not registered")
        }
        let props = propertyNames(for: tool)
        XCTAssertTrue(props.contains("script"))
        XCTAssertTrue(props.contains("timeout_seconds"))
        XCTAssertTrue(props.contains("audit_full_source"))
    }

    func test_runAppleScriptTool_requiresScript() {
        guard let tool = AppleScriptModule.tools.first(where: { $0.name == "run_applescript" }) else {
            return XCTFail("run_applescript tool not registered")
        }
        let required = requiredParams(for: tool)
        XCTAssertTrue(required.contains("script"),
                      "script must be a required parameter")
    }

    func test_runAppleScriptTool_isAnnotatedDestructive() {
        guard let tool = AppleScriptModule.tools.first(where: { $0.name == "run_applescript" }) else {
            return XCTFail("run_applescript tool not registered")
        }
        XCTAssertEqual(tool.annotations.destructiveHint, true)
        XCTAssertEqual(tool.annotations.readOnlyHint, false)
    }

    func test_runAppleScriptTool_descriptionWarnsAboutAuditFullSource() {
        guard let tool = AppleScriptModule.tools.first(where: { $0.name == "run_applescript" }) else {
            return XCTFail("run_applescript tool not registered")
        }
        let desc = tool.description ?? ""
        XCTAssertTrue(desc.lowercased().contains("audit_full_source"),
                      "description must mention the audit_full_source flag")
        XCTAssertTrue(desc.lowercased().contains("pii") || desc.lowercased().contains("secret")
                      || desc.lowercased().contains("password"),
                      "description must warn about PII / secret capture risk")
    }

    func test_unknownToolReturnsNil() async throws {
        let result = try await AppleScriptModule.handle(makeParams(name: "unknown_tool"))
        XCTAssertNil(result)
    }

    func test_isRegisteredInToolRouter() {
        let registered = ToolRouter.modules.contains { $0 == AppleScriptModule.self }
        XCTAssertTrue(registered, "AppleScriptModule must be registered in ToolRouter.modules")
    }

    // MARK: - STORY-007: click_menu_item registration

    func test_registersClickMenuItemTool() {
        let names = AppleScriptModule.tools.map { $0.name }
        XCTAssertTrue(names.contains("click_menu_item"))
    }

    func test_clickMenuItemTool_inputSchema_hasExpectedProperties() {
        guard let tool = AppleScriptModule.tools.first(where: { $0.name == "click_menu_item" }) else {
            return XCTFail("click_menu_item tool not registered")
        }
        let props = propertyNames(for: tool)
        XCTAssertTrue(props.contains("application"))
        XCTAssertTrue(props.contains("path"))
        XCTAssertTrue(props.contains("do_not_activate"))
    }

    func test_clickMenuItemTool_requiresPath() {
        guard let tool = AppleScriptModule.tools.first(where: { $0.name == "click_menu_item" }) else {
            return XCTFail("click_menu_item tool not registered")
        }
        let required = requiredParams(for: tool)
        XCTAssertEqual(required, ["path"],
                       "path must be the only required parameter (application defaults to frontmost)")
    }

    func test_clickMenuItemTool_isAnnotatedDestructive() {
        guard let tool = AppleScriptModule.tools.first(where: { $0.name == "click_menu_item" }) else {
            return XCTFail("click_menu_item tool not registered")
        }
        XCTAssertEqual(tool.annotations.destructiveHint, true)
        XCTAssertEqual(tool.annotations.readOnlyHint, false)
    }

    func test_clickMenuItemTool_descriptionMentionsLocaleSensitivity() {
        guard let tool = AppleScriptModule.tools.first(where: { $0.name == "click_menu_item" }) else {
            return XCTFail("click_menu_item tool not registered")
        }
        let desc = (tool.description ?? "").lowercased()
        XCTAssertTrue(desc.contains("locale"),
                      "description must warn callers that menu names are locale-sensitive")
    }
}
