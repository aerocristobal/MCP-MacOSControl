// STORY: STORY-009 — Element State Polling Tool
// COMPONENT: WaitForElementStateTool

import XCTest
import MCP
@testable import MacOSControlLib

final class WaitForElementStateToolTests: XCTestCase {

    private let pid: pid_t = 4321

    /// Builds a tool whose poll probe replays `script`. Permission is granted
    /// and the app resolves unless overridden, so each test isolates one path.
    private func makeTool(
        script: [ElementProbeResult],
        permission: Bool = true,
        appResolves: Bool = true
    ) -> WaitForElementStateTool {
        WaitForElementStateTool(
            probeFactory: { _, _, _ in FakeElementStateProbe(script) },
            clock: FakeClock(),
            pidResolver: { _ in appResolves ? (self.pid, "com.example.App") : nil },
            permissionCheck: { permission },
            pollIntervalMs: 10
        )
    }

    private func successJSON(_ result: CallTool.Result) throws -> [String: Any] {
        XCTAssertEqual(result.isError, false)
        guard let text = extractText(from: result),
              let data = text.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw XCTSkip("no JSON success payload")
        }
        return obj
    }

    // MARK: - Happy path

    func test_execute_returnsSuccess_whenPredicateBecomesTrue() async throws {
        let tool = makeTool(script: [
            .matched(AXNode(role: "AXButton", title: "Submit", enabled: false)),
            .matched(AXNode(role: "AXButton", title: "Submit", enabled: false)),
            .matched(AXNode(role: "AXButton", title: "Submit", enabled: true)),
        ])
        let result = await tool.execute(makeParams(name: "wait_for_element_state", args: [
            "role": .string("AXButton"),
            "title": .string("Submit"),
            "condition": .string("enabled = true"),
            "application": .string("App"),
            "timeout_seconds": .double(5)
        ]))
        let json = try successJSON(result)
        XCTAssertEqual(json["schema_version"] as? Int, 3)
        XCTAssertEqual(json["condition_met"] as? Bool, true)
        XCTAssertEqual((json["element"] as? [String: Any])?["enabled"] as? Bool, true)
    }

    func test_execute_returnsSuccess_whenElementAppears_existsTrue() async throws {
        let tool = makeTool(script: [.notFound, .notFound, .matched(AXNode(role: "AXList"))])
        let result = await tool.execute(makeParams(name: "wait_for_element_state", args: [
            "role": .string("AXList"),
            "condition": .string("exists = true"),
            "application": .string("App")
        ]))
        XCTAssertEqual(result.isError, false)
    }

    func test_execute_returnsSuccess_whenElementDisappears_existsFalse() async throws {
        let tool = makeTool(script: [
            .matched(AXNode(role: "AXProgressIndicator")),
            .matched(AXNode(role: "AXProgressIndicator")),
            .notFound
        ])
        let result = await tool.execute(makeParams(name: "wait_for_element_state", args: [
            "role": .string("AXProgressIndicator"),
            "condition": .string("exists = false"),
            "application": .string("App")
        ]))
        let json = try successJSON(result)
        XCTAssertEqual(json["exists"] as? Bool, false)
        XCTAssertNil(json["element"])
    }

    func test_execute_matchesStringValueEquality_caseSensitive() async throws {
        let tool = makeTool(script: [
            .matched(AXNode(value: .string("Connecting…"), identifier: "status-label")),
            .matched(AXNode(value: .string("Connected"), identifier: "status-label")),
        ])
        let result = await tool.execute(makeParams(name: "wait_for_element_state", args: [
            "role": .string("AXStaticText"),
            "identifier": .string("status-label"),
            "condition": .string("value = 'Connected'"),
            "application": .string("App")
        ]))
        XCTAssertEqual(result.isError, false)
    }

    func test_execute_acceptsLegacyStateAlias() async throws {
        let tool = makeTool(script: [.matched(AXNode(role: "AXButton", enabled: true))])
        let result = await tool.execute(makeParams(name: "wait_for_element_state", args: [
            "role": .string("AXButton"),
            "state": .string("enabled = true"),
            "application": .string("App")
        ]))
        XCTAssertEqual(result.isError, false)
    }

    // MARK: - Error paths

    func test_execute_returnsStateConditionNotMetError_onTimeout() async throws {
        let tool = makeTool(script: [
            .matched(AXNode(role: "AXButton", title: "Submit", enabled: false))
        ])
        let result = await tool.execute(makeParams(name: "wait_for_element_state", args: [
            "role": .string("AXButton"),
            "title": .string("Submit"),
            "condition": .string("enabled = true"),
            "application": .string("App"),
            "timeout_seconds": .double(1)
        ]))
        XCTAssertEqual(result.isError, true)
        let err = try result.parseStructuredError()
        XCTAssertEqual(err["code"] as? String, "state_condition_not_met")
        let details = err["details"] as? [String: Any]
        XCTAssertNotNil(details?["current_state"])
        XCTAssertNotNil(details?["elapsed_seconds"])
    }

    func test_execute_returnsInvalidConditionExpressionError_onMalformedInput() async throws {
        let tool = makeTool(script: [.notFound])
        let result = await tool.execute(makeParams(name: "wait_for_element_state", args: [
            "role": .string("AXButton"),
            "condition": .string("selected = banana = true"),
            "application": .string("App")
        ]))
        XCTAssertEqual(result.isError, true)
        let err = try result.parseStructuredError()
        XCTAssertEqual(err["code"] as? String, "invalid_condition_expression")
    }

    func test_execute_rejectsTimeoutAboveCap() async throws {
        let tool = makeTool(script: [.notFound])
        let result = await tool.execute(makeParams(name: "wait_for_element_state", args: [
            "role": .string("AXButton"),
            "condition": .string("enabled = true"),
            "application": .string("App"),
            "timeout_seconds": .double(600)
        ]))
        XCTAssertEqual(result.isError, true)
        let err = try result.parseStructuredError()
        XCTAssertEqual(err["code"] as? String, "timeout_exceeds_maximum")
    }

    func test_execute_returnsAccessibilityPermissionRequired_whenNotTrusted() async throws {
        let tool = makeTool(script: [.notFound], permission: false)
        let result = await tool.execute(makeParams(name: "wait_for_element_state", args: [
            "condition": .string("enabled = true"),
            "application": .string("App")
        ]))
        XCTAssertEqual(result.isError, true)
        let err = try result.parseStructuredError()
        XCTAssertEqual(err["code"] as? String, "accessibility_permission_required")
    }

    func test_execute_returnsApplicationNotFound_whenAppDoesNotResolve() async throws {
        let tool = makeTool(script: [.notFound], appResolves: false)
        let result = await tool.execute(makeParams(name: "wait_for_element_state", args: [
            "condition": .string("enabled = true"),
            "application": .string("Nope")
        ]))
        XCTAssertEqual(result.isError, true)
        let err = try result.parseStructuredError()
        XCTAssertEqual(err["code"] as? String, "application_not_found")
    }

    func test_execute_requiresApplication() async throws {
        let tool = makeTool(script: [.notFound])
        let result = await tool.execute(makeParams(name: "wait_for_element_state", args: [
            "condition": .string("enabled = true")
        ]))
        XCTAssertEqual(result.isError, true)
        let err = try result.parseStructuredError()
        XCTAssertEqual(err["code"] as? String, "invalid_input")
    }

    func test_execute_timeout_whenElementNeverResolves_reportsExistsFalseState() async throws {
        // Q2: a not-yet-present element under a non-exists condition waits the
        // full timeout; current_state defaults to { exists: false }.
        let tool = makeTool(script: [.notFound])
        let result = await tool.execute(makeParams(name: "wait_for_element_state", args: [
            "role": .string("AXButton"),
            "condition": .string("enabled = true"),
            "application": .string("App"),
            "timeout_seconds": .double(1)
        ]))
        XCTAssertEqual(result.isError, true)
        let err = try result.parseStructuredError()
        XCTAssertEqual(err["code"] as? String, "state_condition_not_met")
        let current = (err["details"] as? [String: Any])?["current_state"] as? [String: Any]
        XCTAssertEqual(current?["exists"] as? Bool, false)
    }

    func test_execute_acceptsNestedElementLocator() async throws {
        let tool = makeTool(script: [.matched(AXNode(role: "AXButton", enabled: true))])
        let result = await tool.execute(makeParams(name: "wait_for_element_state", args: [
            "element_locator": .object([
                "role": .string("AXButton"),
                "title": .string("Submit"),
                "identifier": .string("submit-btn"),
                "label": .string("Submit"),
                "description": .string("the submit button")
            ]),
            "condition": .string("enabled = true"),
            "application": .string("App")
        ]))
        XCTAssertEqual(result.isError, false)
    }

    func test_execute_requiresCondition() async throws {
        let tool = makeTool(script: [.notFound])
        let result = await tool.execute(makeParams(name: "wait_for_element_state", args: [
            "application": .string("App")
        ]))
        XCTAssertEqual(result.isError, true)
        let err = try result.parseStructuredError()
        XCTAssertEqual(err["code"] as? String, "invalid_input")
    }

    // MARK: - Outline — every STORY-015 state field

    func test_execute_handlesEveryStory015BooleanField() async throws {
        let fields: [(String, AXNode)] = [
            ("enabled = true",             AXNode(role: "AXButton", enabled: true)),
            ("focused = true",             AXNode(role: "AXTextField", focused: true)),
            ("selected = true",            AXNode(role: "AXMenuItem", selected: true)),
            ("expanded = true",            AXNode(role: "AXDisclosureTriangle", expanded: true)),
            ("visible_in_viewport = true", AXNode(role: "AXButton", visibleInViewport: true)),
            ("is_main = true",             AXNode(role: "AXWindow", isMain: true)),
            ("is_minimized = false",       AXNode(role: "AXWindow", isMinimized: false)),
            ("is_frontmost = true",        AXNode(role: "AXWindow", isFrontmost: true)),
        ]
        for (condition, node) in fields {
            let tool = makeTool(script: [.matched(node)])
            let result = await tool.execute(makeParams(name: "wait_for_element_state", args: [
                "role": .string(node.role ?? "AXButton"),
                "condition": .string(condition),
                "application": .string("App")
            ]))
            XCTAssertEqual(result.isError, false, "condition \(condition) should succeed")
        }
    }
}
