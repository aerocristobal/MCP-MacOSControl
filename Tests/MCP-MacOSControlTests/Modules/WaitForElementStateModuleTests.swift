// STORY: STORY-009 — Element State Polling Tool
// COMPONENT: WaitForElementStateModule (module registration + schema audits)

import XCTest
import MCP
@testable import MacOSControlLib

final class WaitForElementStateModuleTests: XCTestCase {

    func test_module_registersExactlyOneTool() {
        XCTAssertEqual(WaitForElementStateModule.tools.count, 1)
    }

    func test_module_registersWaitForElementStateByName() {
        XCTAssertEqual(WaitForElementStateModule.tools.map(\.name), ["wait_for_element_state"])
    }

    func test_module_returnsNil_forUnknownTool() async throws {
        let result = try await WaitForElementStateModule.handle(
            makeParams(name: "something_else")
        )
        XCTAssertNil(result)
    }

    func test_tool_annotations_matchDoD() throws {
        guard let tool = WaitForElementStateModule.tools.first else {
            return XCTFail("tool not registered")
        }
        XCTAssertEqual(tool.annotations.readOnlyHint, true,
                       "DoD: readOnlyHint must be true — the tool only observes")
        XCTAssertEqual(tool.annotations.destructiveHint, false)
        XCTAssertEqual(tool.annotations.idempotentHint, true,
                       "DoD §8: idempotentHint must be true for wait_for_element_state")
        XCTAssertEqual(tool.annotations.openWorldHint, true)
    }

    func test_tool_inputSchema_requiresConditionAndApplication() throws {
        guard let tool = WaitForElementStateModule.tools.first else {
            return XCTFail("tool not registered")
        }
        XCTAssertEqual(Set(requiredParams(for: tool)), ["condition", "application"])
    }

    func test_tool_inputSchema_capsTimeoutAt120() throws {
        guard let tool = WaitForElementStateModule.tools.first,
              case .object(let schema) = tool.inputSchema,
              case .object(let props) = schema["properties"],
              case .object(let timeout) = props["timeout_seconds"],
              case .int(let maximum) = timeout["maximum"] ?? .null
        else {
            return XCTFail("timeout_seconds.maximum missing from schema")
        }
        XCTAssertEqual(maximum, 120)
    }

    func test_tool_description_namesEverySupportedField() throws {
        guard let tool = WaitForElementStateModule.tools.first else {
            return XCTFail("tool not registered")
        }
        let description = tool.description ?? ""
        for field in ConditionField.allNames {
            XCTAssertTrue(description.contains(field),
                          "description must name the supported field \(field)")
        }
    }
}
