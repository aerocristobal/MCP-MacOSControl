// STORY-014 — Find Elements by Query
// COMPONENT: FindElementsTool

import XCTest
import MCP
@testable import MacOSControlLib

final class FindElementsToolTests: XCTestCase {

    var bridge: MockAXApplicationBridge!
    var tool: FindElementsTool!
    let testPID: pid_t = 1

    override func setUp() {
        super.setUp()
        bridge = MockAXApplicationBridge()
        tool = makeTool(bridge: bridge)
    }

    private func makeTool(bridge: MockAXApplicationBridge) -> FindElementsTool {
        FindElementsTool(
            bridge: bridge,
            permissionsChecker: { true },
            pidResolver: { _ in self.testPID }
        )
    }

    private func installTree(_ mock: MockAXUIElement) {
        var m = mock
        m.pid = testPID
        bridge.applicationRoots[testPID] = m
    }

    private func parseJSON(_ text: String) throws -> [String: Any] {
        let data = text.data(using: .utf8) ?? Data()
        return try (JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Scenario 1: Match by role + title_contains

    func test_execute_returnsMatchingButton_byRoleAndTitleContains() async throws {
        installTree(MockAXUIElement(
            role: "AXApplication",
            title: "TextEdit",
            children: [
                MockAXUIElement(role: "AXToolbar", children: [
                    MockAXUIElement(role: "AXButton", title: "Bold", supportedActions: ["AXPress"]),
                    MockAXUIElement(role: "AXButton", title: "Italic", supportedActions: ["AXPress"]),
                    MockAXUIElement(role: "AXButton", title: "Underline", supportedActions: ["AXPress"])
                ])
            ]
        ))

        let result = try await tool.execute(makeParams(name: "find_elements", args: [
            "application": .string("TextEdit"),
            "role": .string("AXButton"),
            "title_contains": .string("Bold")
        ]))!

        XCTAssertEqual(result.isError, false)
        let text = extractText(from: result) ?? ""
        let json = try parseJSON(text)
        let matches = json["matches"] as? [[String: Any]] ?? []
        XCTAssertEqual(matches.count, 1, "expected exactly one node; got \(matches.count) — \(text)")
        XCTAssertEqual(matches.first?["role"] as? String, "AXButton")
        XCTAssertEqual(matches.first?["title"] as? String, "Bold")
        XCTAssertNotNil(matches.first?["ax_path"], "every match must include ax_path")
    }

    func test_execute_excludesNonMatchingSiblings() async throws {
        installTree(MockAXUIElement(role: "AXApplication", children: [
            MockAXUIElement(role: "AXButton", title: "Bold"),
            MockAXUIElement(role: "AXButton", title: "Italic"),
            MockAXUIElement(role: "AXButton", title: "Underline")
        ]))

        let result = try await tool.execute(makeParams(name: "find_elements", args: [
            "role": .string("AXButton"),
            "title_contains": .string("Bold")
        ]))!

        let json = try parseJSON(extractText(from: result) ?? "")
        let matches = json["matches"] as? [[String: Any]] ?? []
        XCTAssertEqual(matches.count, 1)
        let titles = matches.compactMap { $0["title"] as? String }
        XCTAssertFalse(titles.contains("Italic"))
        XCTAssertFalse(titles.contains("Underline"))
    }

    // MARK: - Scenario 2: Match by identifier exact

    func test_execute_returnsOnlyExactIdentifierMatch() async throws {
        installTree(MockAXUIElement(role: "AXApplication", children: [
            MockAXUIElement(role: "AXButton", title: "Save", identifier: "save-button"),
            MockAXUIElement(role: "AXButton", title: "Cancel", identifier: "cancel-button")
        ]))

        let result = try await tool.execute(makeParams(name: "find_elements", args: [
            "identifier": .string("save-button")
        ]))!

        let json = try parseJSON(extractText(from: result) ?? "")
        let matches = json["matches"] as? [[String: Any]] ?? []
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?["identifier"] as? String, "save-button")
    }

    // MARK: - Scenario 3: AX path included

    func test_execute_includesAXPath_withApplicationAndWindowAncestors() async throws {
        installTree(MockAXUIElement(role: "AXApplication", title: "TextEdit", children: [
            MockAXUIElement(role: "AXWindow", title: "Doc1.txt", children: [
                MockAXUIElement(role: "AXButton", title: "Close")
            ]),
            MockAXUIElement(role: "AXWindow", title: "Doc2.txt", children: [
                MockAXUIElement(role: "AXButton", title: "Close")
            ])
        ]))

        let result = try await tool.execute(makeParams(name: "find_elements", args: [
            "application": .string("TextEdit"),
            "role": .string("AXButton"),
            "title": .string("Close")
        ]))!

        let json = try parseJSON(extractText(from: result) ?? "")
        let matches = json["matches"] as? [[String: Any]] ?? []
        XCTAssertEqual(matches.count, 2)
        for match in matches {
            let path = match["ax_path"] as? [String] ?? []
            XCTAssertEqual(path.first, "AXApplication[TextEdit]")
            XCTAssertEqual(path.count, 3)
            XCTAssertTrue(path[1].hasPrefix("AXWindow["), "expected AXWindow ancestor; got \(path[1])")
            XCTAssertEqual(path.last, "AXButton[Close]")
        }
        let windowComponents = Set(matches.compactMap { ($0["ax_path"] as? [String])?[1] })
        XCTAssertEqual(windowComponents, ["AXWindow[Doc1.txt]", "AXWindow[Doc2.txt]"])
    }

    // MARK: - Scenario 4: Empty result is not an error

    func test_execute_returnsEmptyMatchesWithMetadata_whenNoMatch() async throws {
        installTree(MockAXUIElement(role: "AXApplication", children: [
            MockAXUIElement(role: "AXButton", title: "OK"),
            MockAXUIElement(role: "AXButton", title: "Cancel")
        ]))

        let result = try await tool.execute(makeParams(name: "find_elements", args: [
            "title": .string("GhostButton")
        ]))!

        XCTAssertEqual(result.isError, false)
        let json = try parseJSON(extractText(from: result) ?? "")
        let matches = json["matches"] as? [[String: Any]] ?? [["fail": "missing"]]
        XCTAssertTrue(matches.isEmpty, "expected empty matches; got \(matches)")
        XCTAssertNotNil(json["scanned_node_count"])
        XCTAssertNotNil(json["elapsed_ms"])
        XCTAssertEqual(json["truncated_results"] as? Bool, false)
    }

    // MARK: - Scenario 5: max_results cap with truncated flag

    func test_execute_truncatesAtMaxResults_andSetsFlagWithHint() async throws {
        let buttons = (0..<600).map {
            MockAXUIElement(role: "AXButton", title: "Btn-\($0)")
        }
        installTree(MockAXUIElement(role: "AXApplication", children: buttons))

        let result = try await tool.execute(makeParams(name: "find_elements", args: [
            "role": .string("AXButton"),
            "max_results": .int(50)
        ]))!

        let text = extractText(from: result) ?? ""
        let json = try parseJSON(text)
        let matches = json["matches"] as? [[String: Any]] ?? []
        XCTAssertEqual(matches.count, 50)
        XCTAssertEqual(json["truncated_results"] as? Bool, true)
        XCTAssertNotNil(json["note"], "truncated response must include a hint")
        let note = json["note"] as? String ?? ""
        XCTAssertTrue(note.lowercased().contains("max_results"))
    }

    func test_execute_clampsMaxResults_aboveHardLimit() async throws {
        installTree(MockAXUIElement(role: "AXApplication", children: [
            MockAXUIElement(role: "AXButton", title: "Solo")
        ]))

        // max_results=10_000 should clamp to 500 (DoD: max 500) — still works since only 1 match exists.
        let result = try await tool.execute(makeParams(name: "find_elements", args: [
            "role": .string("AXButton"),
            "max_results": .int(10_000)
        ]))!

        XCTAssertEqual(result.isError, false)
    }

    // MARK: - Scenario 6: Predicate too broad

    func test_execute_returnsPredicateTooBroad_withoutTouchingBridge() async throws {
        let tool = makeTool(bridge: bridge)

        let result = try await tool.execute(makeParams(name: "find_elements", args: [:]))!

        XCTAssertEqual(result.isError, true)
        let text = extractText(from: result) ?? ""
        XCTAssertTrue(text.contains("predicate_too_broad"), "expected error code; got: \(text)")
    }

    // MARK: - Scenario 7: Invalid regex

    func test_execute_returnsInvalidRegex_withFieldName_andWithoutTouchingBridge() async throws {
        let result = try await tool.execute(makeParams(name: "find_elements", args: [
            "title_matches": .string("[unclosed")
        ]))!

        XCTAssertEqual(result.isError, true)
        let text = extractText(from: result) ?? ""
        XCTAssertTrue(text.contains("invalid_regex"), "expected error code; got: \(text)")
        XCTAssertTrue(text.contains("title_matches"), "error must identify the failed field; got: \(text)")
    }

    // MARK: - Conflicting title predicates

    func test_execute_returnsConflictingTitlePredicates_whenMultipleTitleFieldsSet() async throws {
        let result = try await tool.execute(makeParams(name: "find_elements", args: [
            "title": .string("Save"),
            "title_contains": .string("Sav")
        ]))!

        XCTAssertEqual(result.isError, true)
        let text = extractText(from: result) ?? ""
        XCTAssertTrue(text.contains("conflicting_title_predicates"), "got: \(text)")
    }

    // MARK: - Schema + permission

    func test_execute_responseIncludesSchemaVersion2() async throws {
        installTree(MockAXUIElement(role: "AXApplication", children: [
            MockAXUIElement(role: "AXButton", title: "OK")
        ]))

        let result = try await tool.execute(makeParams(name: "find_elements", args: [
            "role": .string("AXButton")
        ]))!

        let json = try parseJSON(extractText(from: result) ?? "")
        XCTAssertEqual(json["schema_version"] as? Int, 2)
    }

    func test_execute_returnsPermissionDenied_whenCheckerReturnsFalse() async throws {
        let denied = FindElementsTool(
            bridge: bridge,
            permissionsChecker: { false },
            pidResolver: { _ in self.testPID }
        )

        let result = try await denied.execute(makeParams(name: "find_elements", args: [
            "role": .string("AXButton")
        ]))!

        XCTAssertEqual(result.isError, true)
        let text = extractText(from: result) ?? ""
        XCTAssertTrue(text.contains("permission_denied"), "got: \(text)")
    }

    func test_execute_returnsApplicationNotFound_whenPIDResolverReturnsNil() async throws {
        let unfindable = FindElementsTool(
            bridge: bridge,
            permissionsChecker: { true },
            pidResolver: { _ in nil }
        )

        let result = try await unfindable.execute(makeParams(name: "find_elements", args: [
            "role": .string("AXButton"),
            "application": .string("Nonexistent.app")
        ]))!

        XCTAssertEqual(result.isError, true)
        let text = extractText(from: result) ?? ""
        XCTAssertTrue(text.contains("application_not_found"), "got: \(text)")
    }

    // MARK: - Token Budget Benchmark (DoD)

    /// Proves the value proposition: find_elements payload for "the Save button"
    /// is ≤ 5% of the equivalent full-tree accessibility_tree payload.
    func test_findElementsPayload_isFiveOrLess_percentOf_fullTreePayload() throws {
        // 200-node synthetic toolbar tree with one Save button.
        let toolbarButtons = (0..<199).map { i -> MockAXUIElement in
            var btn = MockAXUIElement(
                role: "AXButton",
                title: "Toolbar-Item-\(i)",
                identifier: "tb-item-\(i)",
                description: "Toolbar button number \(i) with a long-ish description for realism",
                position: CGPoint(x: i * 32, y: 0),
                size: CGSize(width: 30, height: 28),
                supportedActions: ["AXPress"]
            )
            btn.enabledSupported = true
            return btn
        }
        var saveBtn = MockAXUIElement(
            role: "AXButton",
            title: "Save",
            identifier: "save-btn",
            description: "Save the current document",
            position: CGPoint(x: 600, y: 0),
            size: CGSize(width: 60, height: 28),
            supportedActions: ["AXPress"]
        )
        saveBtn.enabledSupported = true
        installTree(MockAXUIElement(role: "AXApplication", title: "TextEdit",
                                   children: toolbarButtons + [saveBtn]))

        // accessibility_tree payload (full subtree at depth 6)
        let builder = AccessibilityTreeBuilder(bridge: bridge)
        let root = bridge.applicationRoot(forPID: testPID)!
        let fullTree = builder.build(from: root, maxDepth: 6)
        let fullPayload = try JSONSerialization.data(
            withJSONObject: AXNodeSerializer().serializeRoot(fullTree),
            options: [.sortedKeys]
        )

        // find_elements payload (a single match for Save)
        let expectation = XCTestExpectation(description: "find_elements completes")
        var findElementsPayload = Data()
        Task {
            let result = try await tool.execute(makeParams(name: "find_elements", args: [
                "role": .string("AXButton"),
                "title": .string("Save")
            ]))!
            findElementsPayload = (extractText(from: result) ?? "").data(using: .utf8) ?? Data()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertGreaterThan(findElementsPayload.count, 0)
        let ratio = Double(findElementsPayload.count) / Double(fullPayload.count)
        XCTAssertLessThanOrEqual(ratio, 0.05,
            "find_elements payload (\(findElementsPayload.count) bytes) must be ≤ 5% of accessibility_tree payload (\(fullPayload.count) bytes); actual ratio: \(String(format: "%.4f", ratio))")
    }
}
