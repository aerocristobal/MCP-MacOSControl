// STORY: STORY-016 — Structured Error Response Contract
// COMPONENT: ElementAtPositionTool coordinates_out_of_bounds details (Scenario 4)
//
// Scenario 4 explicitly requires details.display_bounds describing the valid
// range. The human-readable message still includes the bounds for log-grep, but
// the agent-addressable contract is the structured `details.display_bounds`.

import XCTest
import MCP
@testable import MacOSControlLib

final class CoordinatesOutOfBoundsDetailsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        _ = ErrorCodeRegistry.shared.allRegistrations().count
    }

    func test_outOfBounds_responseIncludesDisplayBoundsObjectInDetails() async throws {
        // Single 1920x1080 display at origin (0,0), matching Scenario 4.
        let displays = [
            DisplayInfo(index: 0, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        ]
        let bridge = MockAXApplicationBridge()
        let tool = ElementAtPositionTool(
            bridge: bridge,
            translator: DisplayCoordinateTranslator(displays: displays),
            validator: DisplayBoundsValidator(displays: displays),
            treeBuilder: AccessibilityTreeBuilder(bridge: bridge),
            permissionsChecker: { true }
        )

        let result = try await tool.execute(
            CallTool.Parameters(name: "element_at_position", arguments: [
                "x": .double(5000),
                "y": .double(5000)
            ])
        )

        let unwrapped = try XCTUnwrap(result)
        XCTAssertEqual(unwrapped.isError, true)
        let inner = try unwrapped.parseStructuredError()
        XCTAssertEqual(inner["code"] as? String, "coordinates_out_of_bounds")

        let details = try XCTUnwrap(inner["details"] as? [String: Any],
                                    "STORY-016 Scenario 4 requires details.display_bounds on coordinates_out_of_bounds")
        let displayBounds = try XCTUnwrap(details["display_bounds"] as? [String: Any],
                                          "details.display_bounds must be present and structured")
        XCTAssertEqual(displayBounds["x"] as? Int, 0)
        XCTAssertEqual(displayBounds["y"] as? Int, 0)
        XCTAssertEqual(displayBounds["width"] as? Int, 1920)
        XCTAssertEqual(displayBounds["height"] as? Int, 1080)
    }
}
