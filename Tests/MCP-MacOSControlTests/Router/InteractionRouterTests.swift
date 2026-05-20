// FILE: Tests/MCP-MacOSControlTests/Router/InteractionRouterTests.swift
// STORY: STORY-010 — Agent Interaction Hierarchy Router
// COMPONENT: InteractionRouter

import XCTest
import CoreGraphics
@testable import MacOSControlLib

final class InteractionRouterTests: XCTestCase {

    var router: InteractionRouter!
    var fakeAXLayer: FakeInteractionLayer!
    var fakeAppleScriptLayer: FakeInteractionLayer!
    var fakeHitTestLayer: FakeInteractionLayer!
    var fakeCoordinateLayer: FakeInteractionLayer!
    var fakeRegistry: StubCapabilityQuerying!

    override func setUp() {
        super.setUp()
        fakeAXLayer = FakeInteractionLayer(name: "ax_semantic")
        fakeAppleScriptLayer = FakeInteractionLayer(name: "applescript")
        fakeHitTestLayer = FakeInteractionLayer(name: "ax_hit_test")
        fakeCoordinateLayer = FakeInteractionLayer(name: "coordinate_fallback")
        fakeRegistry = StubCapabilityQuerying()
        router = InteractionRouter(
            layers: [fakeAXLayer, fakeAppleScriptLayer, fakeHitTestLayer, fakeCoordinateLayer],
            registry: fakeRegistry)
    }

    // MARK: - Happy Path

    func test_route_returnsFirstLayerSuccess() async throws {
        fakeAXLayer.stubbedOutcome = .succeeded(method: "ax_semantic", confidence: 0.95)
        let input = SmartInteractInput(intent: .click, targetDescription: "Bold", application: "TextEdit")
        let result = await router.route(input: input)
        XCTAssertEqual(result.interactionMethod, "ax_semantic")
        // Scenario 1: "confidence between 0.9 and 1.0".
        XCTAssertGreaterThanOrEqual(result.confidence, 0.9)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
        // "decision_log entry showing ax_semantic succeeded on the first attempt".
        XCTAssertEqual(result.decisionLog.count, 1)
        XCTAssertEqual(result.decisionLog[0].layer, "ax_semantic")
        XCTAssertEqual(result.decisionLog[0].outcome, .succeeded)
        XCTAssertTrue(result.decisionLog[0].attempted)
    }

    func test_route_fallsThroughToNextLayer_onSkipped() async throws {
        fakeAXLayer.stubbedOutcome = .skipped(reason: "no AXAction binding")
        fakeAppleScriptLayer.stubbedOutcome = .succeeded(method: "applescript", confidence: 0.85)
        let input = SmartInteractInput(intent: .click, targetDescription: "Open", application: "Script Editor")
        let result = await router.route(input: input)
        XCTAssertEqual(result.interactionMethod, "applescript")
        XCTAssertEqual(result.decisionLog.count, 2)
        XCTAssertEqual(result.decisionLog[0].outcome, .skipped)
        XCTAssertEqual(result.decisionLog[1].outcome, .succeeded)
    }

    func test_route_fallsThroughToNextLayer_onFailed() async throws {
        fakeAXLayer.stubbedOutcome = .failed(errorCode: "ax_action_failed", message: "AXPress returned -25204")
        fakeAppleScriptLayer.stubbedOutcome = .succeeded(method: "applescript", confidence: 0.85)
        let input = SmartInteractInput(intent: .click, targetDescription: "Open", application: "LegacyApp")
        let result = await router.route(input: input)
        XCTAssertEqual(result.interactionMethod, "applescript")
        XCTAssertEqual(result.decisionLog[0].outcome, .failed)
        XCTAssertEqual(result.decisionLog[0].reason, "ax_action_failed: AXPress returned -25204")
    }

    // MARK: - Hit-test layer

    func test_route_usesHitTestLayer_whenAXByNameFailsAndCoordinatesProvided() async throws {
        fakeAXLayer.stubbedOutcome = .failed(errorCode: "element_not_found", message: "no match for 'Submit'")
        fakeAppleScriptLayer.stubbedOutcome = .skipped(reason: "no AppleScript dictionary")
        fakeHitTestLayer.stubbedOutcome = .succeeded(method: "ax_hit_test", confidence: 0.75)
        let input = SmartInteractInput(intent: .click, targetDescription: "Submit",
                                       application: "PartialApp", coordinates: CGPoint(x: 320, y: 180))
        let result = await router.route(input: input)
        XCTAssertEqual(result.interactionMethod, "ax_hit_test")
        let hitTestEntry = result.decisionLog.first { $0.layer == "ax_hit_test" }
        XCTAssertEqual(hitTestEntry?.metadata["coordinates"], "(320.0, 180.0)")
    }

    // MARK: - Type intent

    func test_route_typeIntent_usesTypeSpecificHierarchy() async throws {
        fakeAXLayer.stubbedOutcome = .succeeded(method: "ax_semantic", confidence: 0.95)
        let input = SmartInteractInput(intent: .type, application: "TextEdit", value: "hello world")
        let result = await router.route(input: input)
        XCTAssertEqual(fakeAXLayer.lastIntent, .type)
        XCTAssertEqual(fakeAXLayer.lastValue, "hello world")
        XCTAssertEqual(result.interactionMethod, "ax_semantic")
    }

    func test_route_typeIntent_fallsBackToKeyboardSimulation() async throws {
        fakeAXLayer.stubbedOutcome = .failed(errorCode: "ax_setvalue_unsupported", message: "")
        fakeAppleScriptLayer.stubbedOutcome = .failed(errorCode: "applescript_no_dictionary", message: "")
        fakeHitTestLayer.stubbedOutcome = .skipped(reason: "type intent does not use hit-test")
        fakeCoordinateLayer.stubbedOutcome = .succeeded(method: "coordinate_fallback", confidence: 0.5)
        let input = SmartInteractInput(intent: .type, application: "LegacyApp", value: "hi")
        let result = await router.route(input: input)
        XCTAssertEqual(result.interactionMethod, "coordinate_fallback")
    }

    // MARK: - All Layers Failed

    func test_route_returnsAllLayersFailedError_whenEveryLayerFails() async {
        fakeAXLayer.stubbedOutcome = .failed(errorCode: "frozen_app", message: "timeout")
        fakeAppleScriptLayer.stubbedOutcome = .failed(errorCode: "frozen_app", message: "timeout")
        fakeHitTestLayer.stubbedOutcome = .failed(errorCode: "no_hit_at_position", message: "")
        fakeCoordinateLayer.stubbedOutcome = .failed(errorCode: "rate_limited", message: "")
        let input = SmartInteractInput(intent: .click, targetDescription: "Anything", application: "FrozenApp")
        let result = await router.route(input: input)
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "all_layers_failed")
        XCTAssertEqual((result.details["decision_log"] as? [Any])?.count, 4)
        XCTAssertNotNil(result.details["retry_suggestions"])
    }

    // MARK: - Registry-driven skipping

    func test_route_skipsLayer_whenRegistryDisallows() async throws {
        fakeRegistry.stubCapability(forBundle: "com.electron.exampleapp",
                                    axSupported: false, applescriptSupported: true)
        fakeAppleScriptLayer.stubbedOutcome = .succeeded(method: "applescript", confidence: 0.85)
        let input = SmartInteractInput(intent: .click, targetDescription: "Save",
                                       application: "com.electron.exampleapp")
        let result = await router.route(input: input)
        XCTAssertEqual(fakeAXLayer.callCount, 0, "AX layer should be skipped, not called")
        XCTAssertEqual(result.decisionLog[0].layer, "ax_semantic")
        XCTAssertEqual(result.decisionLog[0].outcome, .skipped)
        XCTAssertFalse(result.decisionLog[0].attempted)
        // Scenario 8: skipped "with reason \"registry: ax_supported=false\"".
        XCTAssertEqual(result.decisionLog[0].reason, "registry: ax_supported=false")
        // "the interaction proceeds directly to the AppleScript layer".
        XCTAssertEqual(result.interactionMethod, "applescript")
    }

    func test_route_acceptsPerCallSkipLayersOverride() async throws {
        fakeAppleScriptLayer.stubbedOutcome = .succeeded(method: "applescript", confidence: 0.85)
        let input = SmartInteractInput(intent: .click, targetDescription: "Save",
                                       application: "TextEdit",
                                       skipLayers: ["ax_semantic"])
        let result = await router.route(input: input)
        XCTAssertEqual(fakeAXLayer.callCount, 0)
        XCTAssertEqual(result.interactionMethod, "applescript")
    }

    // MARK: - Decision log invariants

    func test_decisionLog_isAlwaysNonEmpty_evenOnFirstLayerSuccess() async throws {
        fakeAXLayer.stubbedOutcome = .succeeded(method: "ax_semantic", confidence: 0.95)
        let input = SmartInteractInput(intent: .click, targetDescription: "Bold", application: "TextEdit")
        let result = await router.route(input: input)
        XCTAssertGreaterThanOrEqual(result.decisionLog.count, 1)
    }

    func test_decisionLog_entriesAreOrderedByAttemptTime() async throws {
        fakeAXLayer.stubbedOutcome = .skipped(reason: "no AX")
        fakeAppleScriptLayer.stubbedOutcome = .skipped(reason: "no AS dictionary")
        fakeHitTestLayer.stubbedOutcome = .succeeded(method: "ax_hit_test", confidence: 0.75)
        let input = SmartInteractInput(intent: .click, targetDescription: "X", application: "App",
                                       coordinates: CGPoint(x: 1, y: 1))
        let result = await router.route(input: input)
        XCTAssertEqual(result.decisionLog.map(\.layer),
                       ["ax_semantic", "applescript", "ax_hit_test"])
    }

    // Scenario 9: each decision_log entry is structured —
    // layer, attempted, outcome ∈ {succeeded, skipped, failed}, reason, elapsed_ms.
    func test_decisionLog_everyEntryHasRequiredStructuredFields() async throws {
        fakeAXLayer.stubbedOutcome = .failed(errorCode: "x", message: "y")
        fakeAppleScriptLayer.stubbedOutcome = .skipped(reason: "no dictionary")
        fakeHitTestLayer.stubbedOutcome = .succeeded(method: "ax_hit_test", confidence: 0.75)
        let input = SmartInteractInput(intent: .click, targetDescription: "X", application: "App",
                                       coordinates: CGPoint(x: 1, y: 1))
        let result = await router.route(input: input)
        XCTAssertGreaterThanOrEqual(result.decisionLog.count, 1)
        let allowedOutcomes: Set<String> = ["succeeded", "skipped", "failed"]
        for entry in result.decisionLog {
            let dict = entry.asDictionary
            XCTAssertNotNil(dict["layer"] as? String)
            XCTAssertNotNil(dict["attempted"] as? Bool)
            XCTAssertNotNil(dict["reason"] as? String)
            XCTAssertNotNil(dict["elapsed_ms"] as? Int)
            guard let outcome = dict["outcome"] as? String else {
                return XCTFail("entry missing outcome: \(dict)")
            }
            XCTAssertTrue(allowedOutcomes.contains(outcome), "unexpected outcome \(outcome)")
        }
    }
}
