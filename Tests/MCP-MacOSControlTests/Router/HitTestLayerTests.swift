// FILE: Tests/MCP-MacOSControlTests/Router/HitTestLayerTests.swift
// STORY: STORY-010 — Agent Interaction Hierarchy Router
// COMPONENT: HitTestLayer (adapter over STORY-005 + STORY-003)

import XCTest
import CoreGraphics
@testable import MacOSControlLib

final class HitTestLayerTests: XCTestCase {

    var layer: HitTestLayer!
    var bridge: MockAXApplicationBridge!
    var interactorSpy: AXElementInteractorSpy!

    override func setUp() {
        super.setUp()
        bridge = MockAXApplicationBridge()
        interactorSpy = AXElementInteractorSpy()
        layer = HitTestLayer(bridge: bridge, interactor: interactorSpy)
    }

    func test_attempt_click_resolvesElementAtPositionThenPresses() async {
        bridge.stubbedHitTestResult = MockAXUIElement(role: "AXButton", title: "Submit")
        let outcome = await layer.attempt(.click, target: TargetSpec(coordinates: CGPoint(x: 320, y: 180)))
        guard case .succeeded(let method, _) = outcome else {
            return XCTFail("Expected succeeded, got \(outcome)")
        }
        XCTAssertEqual(method, "ax_hit_test")
        XCTAssertEqual(bridge.hitTestCallCount, 1)
        XCTAssertEqual(bridge.lastHitTestX, 320)
        XCTAssertEqual(bridge.lastHitTestY, 180)
        XCTAssertEqual(interactorSpy.pressCallCount, 1)
    }

    func test_attempt_returnsSkipped_forTypeIntent() async {
        let outcome = await layer.attempt(.type, target: TargetSpec(coordinates: CGPoint(x: 1, y: 1), value: "hi"))
        guard case .skipped = outcome else { return XCTFail("Expected skipped, got \(outcome)") }
        XCTAssertEqual(bridge.hitTestCallCount, 0)
    }

    func test_attempt_returnsSkipped_whenNoCoordinates() async {
        let outcome = await layer.attempt(.click, target: TargetSpec(description: "Submit"))
        guard case .skipped = outcome else { return XCTFail("Expected skipped, got \(outcome)") }
        XCTAssertEqual(bridge.hitTestCallCount, 0)
    }

    func test_attempt_returnsFailed_whenNothingHitTestable() async {
        bridge.stubbedHitTestResult = nil
        let outcome = await layer.attempt(.click, target: TargetSpec(coordinates: CGPoint(x: 9, y: 9)))
        guard case .failed(let code, _) = outcome else { return XCTFail("Expected failed, got \(outcome)") }
        XCTAssertEqual(code, "no_hit_at_position")
    }

    func test_attempt_returnsFailed_whenHitTestRaisesResolutionError() async {
        bridge.stubbedHitTestError = AXResolutionError(detail: "hit-test cannotComplete", underlyingCode: -25204)
        let outcome = await layer.attempt(.click, target: TargetSpec(coordinates: CGPoint(x: 3, y: 3)))
        guard case .failed(let code, _) = outcome else { return XCTFail("Expected failed, got \(outcome)") }
        XCTAssertEqual(code, "ax_resolution_failed")
    }

    func test_attempt_returnsFailed_whenPressRaisesAXActionError() async {
        bridge.stubbedHitTestResult = MockAXUIElement(role: "AXButton", title: "Submit")
        interactorSpy.simulatedError = AXActionError(code: .actionFailed, action: "AXPress", detail: "boom")
        let outcome = await layer.attempt(.click, target: TargetSpec(coordinates: CGPoint(x: 4, y: 4)))
        guard case .failed(let code, _) = outcome else { return XCTFail("Expected failed, got \(outcome)") }
        XCTAssertEqual(code, "ax_action_failed")
    }

    func test_attempt_returnsSkipped_whenAXPermissionDenied() async {
        bridge.stubbedHitTestError = MCPError.permissionDenied("Accessibility permission required for hit-test")
        let outcome = await layer.attempt(.click, target: TargetSpec(coordinates: CGPoint(x: 2, y: 2)))
        guard case .skipped(let reason) = outcome else { return XCTFail("Expected skipped, got \(outcome)") }
        XCTAssertTrue(reason.lowercased().contains("permission"))
    }
}
