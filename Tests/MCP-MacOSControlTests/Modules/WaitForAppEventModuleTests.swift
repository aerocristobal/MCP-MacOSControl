// STORY: STORY-018 — Wait for Application Lifecycle Event Tool
// COMPONENT: WaitForAppEventModule (module registration + schema audits)

import XCTest
import MCP
@testable import MacOSControlLib

final class WaitForAppEventModuleTests: XCTestCase {

    func test_module_registersExactlyOneTool() {
        XCTAssertEqual(WaitForAppEventModule.tools.count, 1)
        XCTAssertEqual(WaitForAppEventModule.tools.map(\.name), ["wait_for_app_event"])
    }

    func test_tool_annotations_matchDoD() throws {
        guard let tool = WaitForAppEventModule.tools.first else {
            return XCTFail("tool not registered")
        }
        XCTAssertEqual(tool.annotations.readOnlyHint, true)
        XCTAssertEqual(tool.annotations.destructiveHint, false)
        XCTAssertEqual(tool.annotations.idempotentHint, false,
                       "DoD: non-idempotent — outcome depends on time-varying lifecycle events")
        XCTAssertEqual(tool.annotations.openWorldHint, true)
    }

    func test_tool_inputSchema_requiresOnlyEvent() throws {
        guard let tool = WaitForAppEventModule.tools.first else {
            return XCTFail("tool not registered")
        }
        XCTAssertEqual(Set(requiredParams(for: tool)), ["event"])
        XCTAssertTrue(propertyNames(for: tool).isSuperset(of: ["event", "bundle_identifier", "timeout_seconds"]))
    }

    func test_tool_inputSchema_constrainsEventToSupportedEnum() throws {
        guard let tool = WaitForAppEventModule.tools.first,
              case .object(let schema) = tool.inputSchema,
              case .object(let props) = schema["properties"],
              case .object(let event) = props["event"],
              case .array(let enumValues) = event["enum"]
        else {
            return XCTFail("event enum constraint missing from schema")
        }
        let names: [String] = enumValues.compactMap {
            if case .string(let s) = $0 { return s }
            return nil
        }
        XCTAssertEqual(Set(names), Set(AppEventType.supported),
                       "schema enum must match the closed supported event set")
    }

    func test_tool_description_namesEverySupportedEvent() throws {
        guard let tool = WaitForAppEventModule.tools.first else {
            return XCTFail("tool not registered")
        }
        let description = tool.description ?? ""
        for event in AppEventType.supported {
            XCTAssertTrue(description.contains(event),
                          "description must name the supported event \(event)")
        }
        XCTAssertTrue(description.contains("300"),
                      "description should advertise the 300s hard cap")
    }

    func test_module_returnsNil_forUnknownTool() async throws {
        let result = try await WaitForAppEventModule.handle(
            makeParams(name: "some_other_tool", args: [:])
        )
        XCTAssertNil(result)
    }
}
