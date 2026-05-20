// FILE: Tests/MCP-MacOSControlTests/Modules/SmartInteractToolTests.swift
// STORY: STORY-010 — Agent Interaction Hierarchy Router
// COMPONENT: SmartInteractTool

import XCTest
import MCP
@testable import MacOSControlLib

final class SmartInteractToolTests: XCTestCase {

    var tool: SmartInteractTool!
    var fakeRouter: FakeInteractionRouter!

    override func setUp() {
        super.setUp()
        fakeRouter = FakeInteractionRouter()
        tool = SmartInteractTool(router: fakeRouter)
    }

    private func errorObject(_ result: CallTool.Result) -> [String: Any]? {
        guard let text = extractText(from: result),
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json["error"] as? [String: Any]
    }

    private func successObject(_ result: CallTool.Result) -> [String: Any]? {
        guard let text = extractText(from: result),
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    func test_execute_validatesRequiredIntent() async {
        let result = await tool.execute(makeParams(name: "smart_interact", args: [
            "application": .string("TextEdit")
        ]))
        XCTAssertEqual(result.isError, true)
        XCTAssertEqual(errorObject(result)?["code"] as? String, "missing_required_field")
        XCTAssertEqual((errorObject(result)?["details"] as? [String: Any])?["field"] as? String, "intent")
    }

    func test_execute_validatesIntentEnum() async {
        let result = await tool.execute(makeParams(name: "smart_interact", args: [
            "intent": .string("telepathy"),
            "application": .string("TextEdit")
        ]))
        XCTAssertEqual(result.isError, true)
        XCTAssertEqual(errorObject(result)?["code"] as? String, "unsupported_intent")
    }

    func test_execute_validatesValueRequiredForTypeIntent() async {
        let result = await tool.execute(makeParams(name: "smart_interact", args: [
            "intent": .string("type"),
            "application": .string("TextEdit")
        ]))
        XCTAssertEqual(result.isError, true)
        XCTAssertEqual(errorObject(result)?["code"] as? String, "missing_required_field")
        XCTAssertEqual((errorObject(result)?["details"] as? [String: Any])?["field"] as? String, "value")
    }

    func test_execute_passesInputToRouterUnchanged() async {
        fakeRouter.stubbedResult = RouterResult(method: "ax_semantic", confidence: 0.95, decisionLog: [])
        let result = await tool.execute(makeParams(name: "smart_interact", args: [
            "intent": .string("click"),
            "target_description": .string("Bold"),
            "application": .string("TextEdit")
        ]))
        XCTAssertNotEqual(result.isError, true)
        XCTAssertEqual(fakeRouter.lastInput?.intent, .click)
        XCTAssertEqual(fakeRouter.lastInput?.application, "TextEdit")
        XCTAssertEqual(fakeRouter.lastInput?.targetDescription, "Bold")
    }

    func test_execute_includesDecisionLogInResponse() async {
        fakeRouter.stubbedResult = RouterResult(
            method: "applescript", confidence: 0.85,
            decisionLog: [
                DecisionLogEntry(layer: "ax_semantic", outcome: .skipped, reason: "no AXAction"),
                DecisionLogEntry(layer: "applescript", outcome: .succeeded, reason: "")
            ])
        let result = await tool.execute(makeParams(name: "smart_interact", args: [
            "intent": .string("click"),
            "application": .string("X")
        ]))
        let log = successObject(result)?["decision_log"] as? [[String: Any]]
        XCTAssertEqual(log?.count, 2)
        XCTAssertEqual(log?[0]["layer"] as? String, "ax_semantic")
        XCTAssertEqual(log?[1]["outcome"] as? String, "succeeded")
    }

    func test_execute_propagatesAllLayersFailedError() async {
        fakeRouter.stubbedResult = RouterResult(
            interactionMethod: "", confidence: 0, decisionLog: [],
            isError: true, errorCode: "all_layers_failed",
            details: ["decision_log": [], "retry_suggestions": ["try again"]])
        let result = await tool.execute(makeParams(name: "smart_interact", args: [
            "intent": .string("click"),
            "application": .string("FrozenApp")
        ]))
        XCTAssertEqual(result.isError, true)
        XCTAssertEqual(errorObject(result)?["code"] as? String, "all_layers_failed")
    }

    func test_execute_parsesCoordinatesAndSkipLayers() async {
        _ = await tool.execute(makeParams(name: "smart_interact", args: [
            "intent": .string("click"),
            "coordinates": .object(["x": .double(320), "y": .double(180)]),
            "skip_layers": .array([.string("coordinate_fallback")])
        ]))
        XCTAssertEqual(fakeRouter.lastInput?.coordinates?.x, 320)
        XCTAssertEqual(fakeRouter.lastInput?.coordinates?.y, 180)
        XCTAssertEqual(fakeRouter.lastInput?.skipLayers, ["coordinate_fallback"])
    }

    func test_execute_addsCoordinateReliabilityWarning() async {
        fakeRouter.stubbedResult = RouterResult(method: "coordinate_fallback", confidence: 0.5, decisionLog: [])
        let result = await tool.execute(makeParams(name: "smart_interact", args: [
            "intent": .string("click"),
            "coordinates": .object(["x": .double(1), "y": .double(2)])
        ]))
        let warning = successObject(result)?["warning"] as? String
        XCTAssertNotNil(warning)
        XCTAssertTrue(warning?.lowercased().contains("least reliable") ?? false)
    }
}
