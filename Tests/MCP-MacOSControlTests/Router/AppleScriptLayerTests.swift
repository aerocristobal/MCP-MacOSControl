// FILE: Tests/MCP-MacOSControlTests/Router/AppleScriptLayerTests.swift
// STORY: STORY-010 — Agent Interaction Hierarchy Router
// COMPONENT: AppleScriptLayer (adapter over STORY-006)

import XCTest
@testable import MacOSControlLib

final class AppleScriptLayerTests: XCTestCase {

    var layer: AppleScriptLayer!
    var executorSpy: AppleScriptExecutorSpy!

    override func setUp() {
        super.setUp()
        executorSpy = AppleScriptExecutorSpy()
        layer = AppleScriptLayer(executor: executorSpy)
    }

    func test_attempt_click_dispatchesActivateScript() async {
        executorSpy.stubbedResult = .success(stdout: "", durationMs: 5)
        let outcome = await layer.attempt(.click, target: TargetSpec(description: "Open", application: "Script Editor"))
        guard case .succeeded(let method, _) = outcome else {
            return XCTFail("Expected succeeded, got \(outcome)")
        }
        XCTAssertEqual(method, "applescript")
        XCTAssertEqual(executorSpy.runCallCount, 1)
        XCTAssertTrue(executorSpy.lastScript?.contains("activate") ?? false)
        XCTAssertTrue(executorSpy.lastScript?.contains("Script Editor") ?? false)
    }

    func test_attempt_returnsSkipped_whenNoApplication() async {
        let outcome = await layer.attempt(.click, target: TargetSpec(description: "Open"))
        guard case .skipped = outcome else {
            return XCTFail("Expected skipped, got \(outcome)")
        }
        XCTAssertEqual(executorSpy.runCallCount, 0)
    }

    func test_attempt_returnsSkipped_forTypeIntent() async {
        let outcome = await layer.attempt(.type, target: TargetSpec(application: "TextEdit", value: "hi"))
        guard case .skipped = outcome else {
            return XCTFail("Expected skipped, got \(outcome)")
        }
        XCTAssertEqual(executorSpy.runCallCount, 0)
    }

    func test_attempt_returnsFailed_whenScriptErrors() async {
        executorSpy.stubbedResult = .failure(.scriptError(code: 1, message: "boom"))
        let outcome = await layer.attempt(.click, target: TargetSpec(description: "Open", application: "BrokenApp"))
        guard case .failed(let code, _) = outcome else {
            return XCTFail("Expected failed, got \(outcome)")
        }
        XCTAssertEqual(code, "applescript_error")
    }
}
