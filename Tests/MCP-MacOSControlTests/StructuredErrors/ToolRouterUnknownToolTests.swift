// STORY: STORY-016 — Structured Error Response Contract
// COMPONENT: ToolRouter unknown-tool fallback (was isError=false; STORY-016 flips to true)

import XCTest
import MCP
@testable import MacOSControlLib

final class ToolRouterUnknownToolTests: XCTestCase {

    override func setUp() {
        super.setUp()
        _ = ErrorCodeRegistry.shared.allRegistrations().count
    }

    func test_unknownTool_returnsIsErrorTrue() async throws {
        let result = try await ToolRouter.handle(
            CallTool.Parameters(name: "completely_made_up_tool_name", arguments: nil)
        )
        XCTAssertEqual(result.isError, true,
                       "STORY-016: unknown-tool fallback must set isError=true (was false pre-016)")
    }

    func test_unknownTool_returnsStructuredUnknownToolCode() async throws {
        let result = try await ToolRouter.handle(
            CallTool.Parameters(name: "completely_made_up_tool_name", arguments: nil)
        )
        let inner = try result.parseStructuredError()
        XCTAssertEqual(inner["code"] as? String, "unknown_tool")
        let message = try XCTUnwrap(inner["message"] as? String)
        XCTAssertTrue(message.contains("completely_made_up_tool_name"),
                      "unknown_tool message should name the requested tool: \(message)")
    }
}
