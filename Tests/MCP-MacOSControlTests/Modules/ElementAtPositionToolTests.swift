import XCTest
import MCP
@testable import MacOSControlLib

final class ElementAtPositionToolTests: XCTestCase {

    var bridgeSpy: MockAXApplicationBridge!
    var translator: DisplayCoordinateTranslator!
    var validator: DisplayBoundsValidator!
    var treeBuilder: AccessibilityTreeBuilder!
    var tool: ElementAtPositionTool!

    override func setUp() {
        super.setUp()
        bridgeSpy = MockAXApplicationBridge()
        let displays = [
            DisplayInfo(index: 0, frame: CGRect(x: 0,    y: 0, width: 1920, height: 1080)),
            DisplayInfo(index: 1, frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080))
        ]
        translator = DisplayCoordinateTranslator(displays: displays)
        validator = DisplayBoundsValidator(displays: displays)
        treeBuilder = AccessibilityTreeBuilder(bridge: bridgeSpy)
        tool = ElementAtPositionTool(
            bridge: bridgeSpy,
            translator: translator,
            validator: validator,
            treeBuilder: treeBuilder,
            permissionsChecker: { true }
        )
    }

    // MARK: - Happy Path (Scenario 1)

    func test_execute_callsBridgeWithGlobalCoordinates() async throws {
        bridgeSpy.stubbedHitTestResult = MockAXUIElement(
            role: "AXButton",
            title: "Save",
            position: CGPoint(x: 380, y: 290),
            size: CGSize(width: 60, height: 30)
        )
        let params = makeParams(name: "element_at_position", args: [
            "x": .double(400),
            "y": .double(300)
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(bridgeSpy.lastHitTestX, 400)
        XCTAssertEqual(bridgeSpy.lastHitTestY, 300)
        XCTAssertEqual(bridgeSpy.hitTestCallCount, 1)
    }

    func test_execute_returnsElementWithRoleAndTitle() async throws {
        bridgeSpy.stubbedHitTestResult = MockAXUIElement(
            role: "AXButton",
            title: "Save"
        )
        let params = makeParams(name: "element_at_position", args: [
            "x": .double(400),
            "y": .double(300)
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, false)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("AXButton"), "expected role; got: \(text)")
        XCTAssertTrue(text.contains("Save"), "expected title; got: \(text)")
    }

    func test_execute_responseIncludesFrameForMatchedElement() async throws {
        bridgeSpy.stubbedHitTestResult = MockAXUIElement(
            role: "AXButton",
            title: "Save",
            position: CGPoint(x: 380, y: 290),
            size: CGSize(width: 60, height: 30)
        )
        let params = makeParams(name: "element_at_position", args: [
            "x": .double(400),
            "y": .double(300)
        ])

        let result = try await tool.execute(params)

        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("\"position\""), "expected position object; got: \(text)")
        XCTAssertTrue(text.contains("\"x\":380"), "expected position.x=380; got: \(text)")
        XCTAssertTrue(text.contains("\"size\""), "expected size object; got: \(text)")
        XCTAssertTrue(text.contains("\"width\":60"), "expected size.width=60; got: \(text)")
    }

    func test_execute_responseIncludesSchemaVersion3() async throws {
        bridgeSpy.stubbedHitTestResult = MockAXUIElement(role: "AXButton", title: "Save")
        let params = makeParams(name: "element_at_position", args: [
            "x": .double(400), "y": .double(300)
        ])

        let result = try await tool.execute(params)

        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("\"schema_version\":3"), "expected schema_version=3; got: \(text)")
    }

    // MARK: - Alternative Success (Scenario 2)

    func test_execute_includesSettableTrue_forTextField() async throws {
        bridgeSpy.stubbedHitTestResult = MockAXUIElement(
            role: "AXTextField",
            label: "Search",
            valueSettable: true
        )
        let params = makeParams(name: "element_at_position", args: [
            "x": .double(200),
            "y": .double(150)
        ])

        let result = try await tool.execute(params)

        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("\"role\":\"AXTextField\""),
                      "expected role=AXTextField; got: \(text)")
        XCTAssertTrue(text.contains("\"settable\":true"),
                      "expected settable=true; got: \(text)")
    }

    // STORY-015 — Scenario 6: focused surfaces through element_at_position
    // (proves the serializer is the single source of truth for the per-node shape).
    func test_execute_includesFocused_whenElementIsFocused() async throws {
        bridgeSpy.stubbedHitTestResult = MockAXUIElement(
            role: "AXTextField",
            label: "Search",
            focused: true
        )
        let params = makeParams(name: "element_at_position", args: [
            "x": .double(200),
            "y": .double(150)
        ])

        let result = try await tool.execute(params)

        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("\"focused\":true"),
                      "expected focused=true; got: \(text)")
        XCTAssertFalse(text.contains("visible_in_viewport"),
                       "shallow build must omit visible_in_viewport; got: \(text)")
    }

    // MARK: - Boundary (Scenario 3)

    func test_execute_returnsApplicationRoot_whenNoSpecificElementAtCoords() async throws {
        bridgeSpy.stubbedHitTestResult = MockAXUIElement(
            role: "AXApplication",
            title: "Finder"
        )
        let params = makeParams(name: "element_at_position", args: [
            "x": .double(10),
            "y": .double(10)
        ])

        let result = try await tool.execute(params)

        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("AXApplication"))
        XCTAssertTrue(text.contains("no interactive element"),
                      "response must surface the empty-area note; got: \(text)")
    }

    // MARK: - Error: Out of Bounds (Scenario 4)

    func test_execute_rejectsCoords_outsideDisplayUnion() async throws {
        let params = makeParams(name: "element_at_position", args: [
            "x": .double(5000),
            "y": .double(5000)
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("coordinates_out_of_bounds"),
                      "expected coordinates_out_of_bounds error; got: \(text)")
        XCTAssertTrue(text.contains("3840"),
                      "error must include display union dimensions; got: \(text)")
    }

    func test_execute_doesNotInvokeBridge_whenOutOfBounds() async throws {
        let params = makeParams(name: "element_at_position", args: [
            "x": .double(5000),
            "y": .double(5000)
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(bridgeSpy.hitTestCallCount, 0,
                       "bridge must not be invoked for out-of-bounds coords")
    }

    // MARK: - Error: Non-Finite (Scenario 5)

    func test_execute_rejectsNaN_x() async throws {
        let params = makeParams(name: "element_at_position", args: [
            "x": .double(.nan),
            "y": .double(100)
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("invalid_coordinates"), "got: \(text)")
        XCTAssertEqual(bridgeSpy.hitTestCallCount, 0)
    }

    func test_execute_rejectsInfinite_y() async throws {
        let params = makeParams(name: "element_at_position", args: [
            "x": .double(100),
            "y": .double(.infinity)
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("invalid_coordinates"), "got: \(text)")
        XCTAssertEqual(bridgeSpy.hitTestCallCount, 0)
    }

    // MARK: - display_index translation

    func test_execute_translatesDisplayLocalCoords_toGlobal() async throws {
        bridgeSpy.stubbedHitTestResult = MockAXUIElement(role: "AXButton", title: "OK")
        // x=100 on display 1 (origin 1920,0) should hit at global x=2020.
        let params = makeParams(name: "element_at_position", args: [
            "x": .double(100),
            "y": .double(50),
            "display_index": .int(1)
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(bridgeSpy.lastHitTestX, 2020)
        XCTAssertEqual(bridgeSpy.lastHitTestY, 50)
    }

    func test_execute_passesThroughCoords_whenDisplayIndexOmitted() async throws {
        bridgeSpy.stubbedHitTestResult = MockAXUIElement(role: "AXButton", title: "OK")
        let params = makeParams(name: "element_at_position", args: [
            "x": .double(2020),
            "y": .double(50)
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(bridgeSpy.lastHitTestX, 2020,
                       "without display_index, coords are treated as global")
    }

    func test_execute_rejectsUnknownDisplayIndex() async throws {
        let params = makeParams(name: "element_at_position", args: [
            "x": .double(100),
            "y": .double(50),
            "display_index": .int(99)
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("unknown_display_index"), "got: \(text)")
        XCTAssertEqual(bridgeSpy.hitTestCallCount, 0,
                       "bridge must not be invoked for unknown display_index")
    }

    // MARK: - Permission

    func test_execute_returnsPermissionDenied_whenCheckerReturnsFalse() async throws {
        tool = ElementAtPositionTool(
            bridge: bridgeSpy,
            translator: translator,
            validator: validator,
            treeBuilder: treeBuilder,
            permissionsChecker: { false }
        )
        let params = makeParams(name: "element_at_position", args: [
            "x": .double(100),
            "y": .double(100)
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("permission_denied"), "got: \(text)")
        XCTAssertEqual(bridgeSpy.hitTestCallCount, 0)
    }
}
