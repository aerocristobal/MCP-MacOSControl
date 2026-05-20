// FILE: Tests/MCP-MacOSControlTests/Router/AXSemanticLayerTests.swift
// STORY: STORY-010 — Agent Interaction Hierarchy Router
// COMPONENT: AXSemanticLayer (adapter over STORY-002/003)

import XCTest
@testable import MacOSControlLib

final class AXSemanticLayerTests: XCTestCase {

    var layer: AXSemanticLayer!
    var resolverSpy: AXElementResolverSpy!
    var interactorSpy: AXElementInteractorSpy!

    override func setUp() {
        super.setUp()
        resolverSpy = AXElementResolverSpy()
        interactorSpy = AXElementInteractorSpy()
        layer = AXSemanticLayer(resolver: resolverSpy, interactor: interactorSpy)
    }

    func test_attempt_click_dispatchesPressOnResolvedElement() async {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "Bold", identifier: "ax-bold-1")
        let outcome = await layer.attempt(.click, target: TargetSpec(description: "Bold", application: "TextEdit"))
        guard case .succeeded(let method, _) = outcome else {
            return XCTFail("Expected succeeded, got \(outcome)")
        }
        XCTAssertEqual(method, "ax_semantic")
        XCTAssertEqual(interactorSpy.pressCallCount, 1)
        XCTAssertEqual(resolverSpy.callCount, 1)
    }

    func test_attempt_type_dispatchesAXSetValueActionNotPress() async {
        resolverSpy.stubbedResult = .mockReference(role: "AXTextArea", title: "Body")
        let outcome = await layer.attempt(.type, target: TargetSpec(description: "Body", application: "TextEdit", value: "hi"))
        guard case .succeeded = outcome else {
            return XCTFail("Expected succeeded, got \(outcome)")
        }
        XCTAssertEqual(interactorSpy.lastAction, AXSemanticLayer.typeActionToken)
        XCTAssertEqual(interactorSpy.pressCallCount, 0)
    }

    func test_attempt_returnsSkipped_whenAXPermissionDenied() async {
        resolverSpy.stubbedError = MCPError.permissionDenied("Accessibility permission required")
        let outcome = await layer.attempt(.click, target: TargetSpec(description: "X", application: "Y"))
        guard case .skipped(let reason) = outcome else {
            return XCTFail("Expected skipped, got \(outcome)")
        }
        XCTAssertTrue(reason.lowercased().contains("permission"))
    }

    func test_attempt_returnsFailed_whenElementNotFound() async {
        resolverSpy.stubbedError = AXNotFoundError(searchCriteria: "title=Ghost")
        let outcome = await layer.attempt(.click, target: TargetSpec(description: "Ghost", application: "Y"))
        guard case .failed(let code, _) = outcome else {
            return XCTFail("Expected failed, got \(outcome)")
        }
        XCTAssertEqual(code, "element_not_found")
    }

    func test_attempt_returnsFailed_whenResolutionErrors() async {
        resolverSpy.stubbedError = AXResolutionError(detail: "AX C-API cannotComplete", underlyingCode: -25204)
        let outcome = await layer.attempt(.click, target: TargetSpec(description: "X", application: "Y"))
        guard case .failed(let code, _) = outcome else { return XCTFail("Expected failed, got \(outcome)") }
        XCTAssertEqual(code, "ax_resolution_failed")
    }

    func test_attempt_returnsSkipped_whenPressHitsPermissionDenied() async {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "Bold")
        interactorSpy.simulatedError = MCPError.accessibilityPermissionRequired
        let outcome = await layer.attempt(.click, target: TargetSpec(description: "Bold", application: "Y"))
        guard case .skipped(let reason) = outcome else { return XCTFail("Expected skipped, got \(outcome)") }
        XCTAssertTrue(reason.lowercased().contains("permission"))
    }

    func test_attempt_returnsFailed_whenPressRaisesAXActionError() async {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "Bold")
        interactorSpy.simulatedError = AXActionError(code: .actionFailed, action: "AXPress", detail: "returned -25204", underlyingCode: -25204)
        let outcome = await layer.attempt(.click, target: TargetSpec(description: "Bold", application: "Y"))
        guard case .failed(let code, _) = outcome else { return XCTFail("Expected failed, got \(outcome)") }
        XCTAssertEqual(code, "ax_action_failed")
    }

    func test_attempt_returnsFailed_whenPressRaisesGenericError() async {
        struct Boom: Error {}
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "Bold")
        interactorSpy.simulatedError = Boom()
        let outcome = await layer.attempt(.click, target: TargetSpec(description: "Bold", application: "Y"))
        guard case .failed(let code, _) = outcome else { return XCTFail("Expected failed, got \(outcome)") }
        XCTAssertEqual(code, "ax_action_failed")
    }

    func test_attempt_returnsSkipped_whenNoTargetDescription() async {
        let outcome = await layer.attempt(.click, target: TargetSpec(application: "Y"))
        guard case .skipped = outcome else {
            return XCTFail("Expected skipped, got \(outcome)")
        }
        XCTAssertEqual(resolverSpy.callCount, 0)
    }
}
