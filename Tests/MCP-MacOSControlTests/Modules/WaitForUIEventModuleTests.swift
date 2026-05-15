// STORY: STORY-008 — AXObserver Wait for UI Event Tool
// COMPONENT: WaitForUIEventModule (module registration + schema audits)

import XCTest
import MCP
@testable import MacOSControlLib

final class WaitForUIEventModuleTests: XCTestCase {

    func test_module_registersExactlyOneTool() {
        XCTAssertEqual(WaitForUIEventModule.tools.count, 1)
    }

    func test_module_registersWaitForUIEventByName() {
        let names = WaitForUIEventModule.tools.map(\.name)
        XCTAssertEqual(names, ["wait_for_ui_event"])
    }

    func test_tool_annotations_matchDoD() throws {
        guard let tool = WaitForUIEventModule.tools.first else {
            return XCTFail("tool not registered")
        }
        XCTAssertEqual(tool.annotations.readOnlyHint, true,
                       "DoD: readOnlyHint must be true — the tool does not mutate UI state")
        XCTAssertEqual(tool.annotations.destructiveHint, false,
                       "tool only observes, never dispatches actions")
        XCTAssertEqual(tool.annotations.idempotentHint, false,
                       "DoD: idempotentHint must be false — outcome depends on time-varying UI events")
        XCTAssertEqual(tool.annotations.openWorldHint, true,
                       "DoD: openWorldHint must be true — tool observes external macOS UI")
    }

    func test_tool_inputSchema_requiresNotificationAndApplication() throws {
        guard let tool = WaitForUIEventModule.tools.first else {
            return XCTFail("tool not registered")
        }
        let required = Set(requiredParams(for: tool))
        XCTAssertEqual(required, ["notification", "application"])
    }

    func test_tool_inputSchema_constrainsNotificationToSupportedEnum() throws {
        guard let tool = WaitForUIEventModule.tools.first,
              case .object(let schema) = tool.inputSchema,
              case .object(let props) = schema["properties"],
              case .object(let notification) = props["notification"],
              case .array(let enumValues) = notification["enum"]
        else {
            return XCTFail("notification enum constraint missing from schema")
        }
        let names: [String] = enumValues.compactMap {
            if case .string(let s) = $0 { return s }
            return nil
        }
        XCTAssertEqual(Set(names), Set(AXObserverNotification.supported),
                       "schema enum must match the closed supported notification set")
    }

    func test_tool_description_namesEveryDoDListedNotification() throws {
        guard let tool = WaitForUIEventModule.tools.first else {
            return XCTFail("tool not registered")
        }
        let description = tool.description ?? ""
        for notification in AXObserverNotification.supported {
            XCTAssertTrue(description.contains(notification),
                          "description must name the supported notification \(notification)")
        }
    }

    func test_tool_description_mentionsMultiplexingAndTimeoutCap() throws {
        guard let tool = WaitForUIEventModule.tools.first else {
            return XCTFail("tool not registered")
        }
        let description = tool.description ?? ""
        XCTAssertTrue(description.lowercased().contains("multiplex")
                      || description.contains("share"),
                      "description should advertise the multiplexing optimization")
        XCTAssertTrue(description.contains("300"),
                      "description should advertise the 300s hard cap")
    }

    func test_module_returnsNil_forUnknownTool() async throws {
        let result = try await WaitForUIEventModule.handle(
            makeParams(name: "some_other_tool", args: [:])
        )
        XCTAssertNil(result)
    }
}
