// FILE: Tests/MCP-MacOSControlTests/Router/CoordinateLayerTests.swift
// STORY: STORY-010 — Agent Interaction Hierarchy Router
// COMPONENT: CoordinateLayer (adapter over MouseControl / KeyboardControl)

import XCTest
import CoreGraphics
@testable import MacOSControlLib

final class CoordinateLayerTests: XCTestCase {

    var layer: CoordinateLayer!
    var actuator: FakeCoordinateActuator!

    override func setUp() {
        super.setUp()
        actuator = FakeCoordinateActuator()
        layer = CoordinateLayer(actuator: actuator)
    }

    func test_attempt_click_dispatchesToMouseClick() async {
        let outcome = await layer.attempt(.click, target: TargetSpec(coordinates: CGPoint(x: 500, y: 400)))
        guard case .succeeded(let method, let confidence) = outcome else {
            return XCTFail("Expected succeeded, got \(outcome)")
        }
        XCTAssertEqual(method, "coordinate_fallback")
        XCTAssertEqual(confidence, 0.5, accuracy: 0.0001)
        XCTAssertEqual(actuator.clickCallCount, 1)
        XCTAssertEqual(actuator.lastClick?.x, 500)
        XCTAssertEqual(actuator.lastClick?.y, 400)
    }

    func test_attempt_click_returnsSkipped_whenNoCoordinates() async {
        let outcome = await layer.attempt(.click, target: TargetSpec(description: "Bold"))
        guard case .skipped = outcome else { return XCTFail("Expected skipped, got \(outcome)") }
        XCTAssertEqual(actuator.clickCallCount, 0)
    }

    func test_attempt_type_focusesThenTypes() async {
        let outcome = await layer.attempt(.type, target: TargetSpec(coordinates: CGPoint(x: 10, y: 20), value: "hello"))
        guard case .succeeded = outcome else { return XCTFail("Expected succeeded, got \(outcome)") }
        XCTAssertEqual(actuator.clickCallCount, 1, "should click to focus the field first")
        XCTAssertEqual(actuator.typedText, ["hello"])
    }

    func test_attempt_returnsFailed_whenActuatorThrows() async {
        actuator.clickError = MCPError.inputFailed("CGEvent post failed")
        let outcome = await layer.attempt(.click, target: TargetSpec(coordinates: CGPoint(x: 1, y: 2)))
        guard case .failed(let code, _) = outcome else { return XCTFail("Expected failed, got \(outcome)") }
        XCTAssertEqual(code, "input_failed")
    }
}
