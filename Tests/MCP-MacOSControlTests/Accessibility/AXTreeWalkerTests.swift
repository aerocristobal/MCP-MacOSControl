// STORY-014 — Find Elements by Query
// COMPONENT: AXTreeWalker

import XCTest
@testable import MacOSControlLib

final class AXTreeWalkerTests: XCTestCase {

    var bridge: MockAXApplicationBridge!
    var walker: AXTreeWalker!

    override func setUp() {
        super.setUp()
        bridge = MockAXApplicationBridge()
        walker = AXTreeWalker(bridge: bridge)
    }

    private func installRoot(_ mock: MockAXUIElement, pid: pid_t = 1) -> AXElementReference {
        var m = mock
        m.pid = pid
        bridge.applicationRoots[pid] = m
        return bridge.applicationRoot(forPID: pid)!
    }

    // MARK: - Limit Enforcement (Scenario 5)

    func test_walk_stopsAtMaxResults_andSetsTruncatedFlag() throws {
        let buttons = (0..<100).map {
            MockAXUIElement(role: "AXButton", title: "Button-\($0)")
        }
        let root = installRoot(MockAXUIElement(role: "AXApplication", children: buttons))
        let predicate = try ElementPredicate.compile(from: FindElementsInput(role: "AXButton"))

        let result = walker.walk(from: root, matching: predicate, maxDepth: 6, maxResults: 50)

        XCTAssertEqual(result.matches.count, 50)
        XCTAssertTrue(result.truncatedResults,
                      "truncated_results must be true when max_results cap is reached and matches remain")
        XCTAssertEqual(result.scannedNodeCount, 51,
                       "Walker visited root + 50 children before stopping (BFS short-circuit)")
    }

    func test_walk_noTruncation_whenAllMatchesFitUnderCap() throws {
        let buttons = (0..<5).map {
            MockAXUIElement(role: "AXButton", title: "Button-\($0)")
        }
        let root = installRoot(MockAXUIElement(role: "AXApplication", children: buttons))
        let predicate = try ElementPredicate.compile(from: FindElementsInput(role: "AXButton"))

        let result = walker.walk(from: root, matching: predicate, maxDepth: 6, maxResults: 50)

        XCTAssertEqual(result.matches.count, 5)
        XCTAssertFalse(result.truncatedResults)
    }

    // MARK: - BFS Ordering

    func test_walk_returnsShallowMatchesBeforeDeepMatches() throws {
        // Same-titled button at depth 5 and at depth 1; BFS must surface the shallow one first.
        let deepButton = MockAXUIElement(role: "AXButton", title: "Save")
        var deepest = deepButton
        for _ in 0..<4 {
            deepest = MockAXUIElement(role: "AXGroup", children: [deepest])
        }
        let shallowButton = MockAXUIElement(role: "AXButton", title: "Save")
        let root = installRoot(MockAXUIElement(
            role: "AXApplication", children: [deepest, shallowButton]
        ))
        let predicate = try ElementPredicate.compile(from: FindElementsInput(role: "AXButton", title: "Save"))

        let result = walker.walk(from: root, matching: predicate, maxDepth: 12, maxResults: 1)

        XCTAssertEqual(result.matches.count, 1)
        XCTAssertEqual(result.matches.first?.ancestors.count, 1,
                       "BFS must return the shallow match (1 ancestor: AXApplication) before the deep match (5 ancestors)")
        XCTAssertTrue(result.truncatedResults,
                      "deep match remains in queue → truncated_results=true")
    }

    // MARK: - Depth Boundary

    func test_walk_doesNotDescendBeyondMaxDepth() throws {
        var node = MockAXUIElement(role: "AXButton", title: "Hidden")
        for _ in 0..<10 {
            node = MockAXUIElement(role: "AXGroup", children: [node])
        }
        let root = installRoot(MockAXUIElement(role: "AXApplication", children: [node]))
        let predicate = try ElementPredicate.compile(from: FindElementsInput(role: "AXButton"))

        let result = walker.walk(from: root, matching: predicate, maxDepth: 5, maxResults: 50)

        XCTAssertEqual(result.matches.count, 0,
                       "Walker must not descend past max_depth even when matches exist below")
    }

    func test_walk_includesMatchAtExactlyMaxDepth() throws {
        // Build a chain: app (depth 0) -> group (depth 1) -> button (depth 2)
        let button = MockAXUIElement(role: "AXButton", title: "Target")
        let group = MockAXUIElement(role: "AXGroup", children: [button])
        let root = installRoot(MockAXUIElement(role: "AXApplication", children: [group]))
        let predicate = try ElementPredicate.compile(from: FindElementsInput(role: "AXButton"))

        let result = walker.walk(from: root, matching: predicate, maxDepth: 2, maxResults: 50)

        XCTAssertEqual(result.matches.count, 1, "node at exactly max_depth should be included")
    }

    // MARK: - Path Reconstruction (Scenario 3)

    func test_walk_capturesAncestorsForEachMatch() throws {
        let close = MockAXUIElement(role: "AXButton", title: "Close")
        let window = MockAXUIElement(role: "AXWindow", title: "Untitled.txt", children: [close])
        let root = installRoot(MockAXUIElement(role: "AXApplication", title: "TextEdit", children: [window]))
        let predicate = try ElementPredicate.compile(from: FindElementsInput(role: "AXButton", title: "Close"))

        let result = walker.walk(from: root, matching: predicate, maxDepth: 6, maxResults: 50)

        XCTAssertEqual(result.matches.count, 1)
        let match = result.matches[0]
        XCTAssertEqual(match.ancestors.count, 2)
        XCTAssertEqual(match.ancestors[0].role, "AXApplication")
        XCTAssertEqual(match.ancestors[0].title, "TextEdit")
        XCTAssertEqual(match.ancestors[1].role, "AXWindow")
        XCTAssertEqual(match.ancestors[1].title, "Untitled.txt")
        XCTAssertEqual(match.reference.title, "Close")
    }

    // MARK: - Empty Result

    func test_walk_returnsEmptyMatches_withoutTruncation_whenNothingMatches() throws {
        let labels = (0..<10).map {
            MockAXUIElement(role: "AXStaticText", title: "Label-\($0)")
        }
        let root = installRoot(MockAXUIElement(role: "AXApplication", children: labels))
        let predicate = try ElementPredicate.compile(from: FindElementsInput(role: "AXButton"))

        let result = walker.walk(from: root, matching: predicate, maxDepth: 6, maxResults: 50)

        XCTAssertEqual(result.matches.count, 0)
        XCTAssertFalse(result.truncatedResults)
        XCTAssertEqual(result.scannedNodeCount, 11, "root + 10 labels visited")
    }
}
