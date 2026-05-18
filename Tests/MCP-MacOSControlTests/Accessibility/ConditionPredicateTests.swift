// STORY: STORY-009 — Element State Polling Tool
// COMPONENT: ConditionPredicate (evaluates a ParsedCondition vs an ElementProbeResult)

import XCTest
@testable import MacOSControlLib

final class ConditionPredicateTests: XCTestCase {

    private func predicate(_ expr: String) throws -> ConditionPredicate {
        ConditionPredicate(try ConditionExpressionParser().parse(expr))
    }

    // MARK: - exists

    func test_exists_true_matchesWhenElementResolved() throws {
        let p = try predicate("exists = true")
        XCTAssertTrue(p.evaluate(.matched(AXNode(role: "AXList"))))
        XCTAssertFalse(p.evaluate(.notFound))
    }

    func test_exists_false_matchesWhenElementGone() throws {
        let p = try predicate("exists = false")
        XCTAssertTrue(p.evaluate(.notFound))
        XCTAssertFalse(p.evaluate(.matched(AXNode(role: "AXProgressIndicator"))))
    }

    // MARK: - boolean state fields

    func test_booleanField_matchesOnlyWhenNodePropertyEqualsTarget() throws {
        let p = try predicate("enabled = true")
        XCTAssertTrue(p.evaluate(.matched(AXNode(role: "AXButton", enabled: true))))
        XCTAssertFalse(p.evaluate(.matched(AXNode(role: "AXButton", enabled: false))))
    }

    func test_booleanField_nilPropertyIsNotAMatch() throws {
        let p = try predicate("focused = true")
        // focused not populated → still waiting, not a match.
        XCTAssertFalse(p.evaluate(.matched(AXNode(role: "AXTextField"))))
    }

    func test_booleanField_notFoundIsNotAMatch() throws {
        let p = try predicate("selected = true")
        XCTAssertFalse(p.evaluate(.notFound))
    }

    func test_eachStory015Field_isReadFromItsOwnProperty() throws {
        XCTAssertTrue(try predicate("selected = true")
            .evaluate(.matched(AXNode(role: "AXMenuItem", selected: true))))
        XCTAssertTrue(try predicate("expanded = true")
            .evaluate(.matched(AXNode(role: "AXDisclosureTriangle", expanded: true))))
        XCTAssertTrue(try predicate("visible_in_viewport = true")
            .evaluate(.matched(AXNode(role: "AXButton", visibleInViewport: true))))
        XCTAssertTrue(try predicate("is_main = true")
            .evaluate(.matched(AXNode(role: "AXWindow", isMain: true))))
        XCTAssertTrue(try predicate("is_minimized = false")
            .evaluate(.matched(AXNode(role: "AXWindow", isMinimized: false))))
        XCTAssertTrue(try predicate("is_frontmost = true")
            .evaluate(.matched(AXNode(role: "AXWindow", isFrontmost: true))))
    }

    // MARK: - value equality

    func test_value_exactCaseSensitiveStringMatch() throws {
        let p = try predicate("value = 'Connected'")
        XCTAssertTrue(p.evaluate(.matched(AXNode(value: .string("Connected")))))
        XCTAssertFalse(p.evaluate(.matched(AXNode(value: .string("connected")))))
        XCTAssertFalse(p.evaluate(.matched(AXNode(value: .string("Connecting…")))))
        XCTAssertFalse(p.evaluate(.notFound))
    }

    func test_value_numericIsStringified() throws {
        let p = try predicate("value = '42'")
        XCTAssertTrue(p.evaluate(.matched(AXNode(value: .number(42)))))
    }
}
