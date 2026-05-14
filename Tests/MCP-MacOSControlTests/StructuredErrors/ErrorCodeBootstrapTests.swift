// STORY: STORY-016 — Structured Error Response Contract
// COMPONENT: ErrorCodeBootstrap — verifies every code emitted by Sources/ is registered

import XCTest
@testable import MacOSControlLib

final class ErrorCodeBootstrapTests: XCTestCase {

    override func setUp() {
        super.setUp()
        _ = ErrorCodeRegistry.shared.allRegistrations().count
    }

    func test_bootstrap_registersAllConsumerStoryReservedCodes() {
        let expected: Set<String> = [
            // MCPError-backed
            "permission_denied", "window_not_found", "mirroring_not_running",
            "mirroring_not_available", "calibration_failed", "invalid_coordinates",
            "input_failed", "mirroring_disconnected", "rate_limited", "timeout",
            "applescript_error", "execution_timeout", "security_policy_violation",
            "automation_permission_required", "no_frontmost_application",
            "accessibility_permission_required",
            // AX errors
            "ax_not_found", "ax_resolution_failed",
            "ax_element_disabled", "ax_action_unsupported", "ax_action_failed",
            // FindElementsError
            "predicate_too_broad", "invalid_regex",
            "conflicting_title_predicates", "conflicting_identifier_predicates",
            // Reserved consumer-story codes
            "coordinates_out_of_bounds", "menu_item_not_found", "menu_item_disabled",
            "wait_timeout", "state_condition_not_met",
            // System / router
            "invalid_input", "backend_error", "unknown_tool", "internal_error",
            "action_not_supported", "element_not_found", "action_failed",
            "application_not_found", "predicate_compile_failed", "unknown_display_index"
        ]
        let registered = Set(ErrorCodeRegistry.shared.allRegistrations().map { $0.code })
        let missing = expected.subtracting(registered)
        XCTAssertTrue(missing.isEmpty,
                      "ErrorCodeBootstrap is missing registrations for: \(missing.sorted())")
    }

    func test_bootstrap_codesAllValidSnakeCase() throws {
        let regex = try NSRegularExpression(pattern: ErrorCodeRegistry.codeRegex)
        for reg in ErrorCodeRegistry.shared.allRegistrations() {
            let range = NSRange(reg.code.startIndex..<reg.code.endIndex, in: reg.code)
            XCTAssertNotNil(regex.firstMatch(in: reg.code, range: range),
                            "registered code violates snake_case regex: \(reg.code)")
            XCTAssertLessThanOrEqual(reg.code.count, ErrorCodeRegistry.maxCodeLength,
                                     "registered code exceeds length cap: \(reg.code)")
        }
    }

    func test_bootstrap_isIdempotent_onFreshRegistry() throws {
        let r = ErrorCodeRegistry()
        XCTAssertNoThrow(try ErrorCodeBootstrap.register(into: r))
        let firstCount = r.allRegistrations().count
        XCTAssertGreaterThan(firstCount, 30, "bootstrap should register 30+ codes")
        // Re-running on a fresh registry should produce the same count (idempotent definition).
        let r2 = ErrorCodeRegistry()
        try ErrorCodeBootstrap.register(into: r2)
        XCTAssertEqual(r.allRegistrations().count, r2.allRegistrations().count)
    }

    func test_bootstrap_throwsCollision_whenCalledTwiceOnSameRegistry() throws {
        let r = ErrorCodeRegistry()
        try ErrorCodeBootstrap.register(into: r)
        // Second call should collide on the first code attempted.
        XCTAssertThrowsError(try ErrorCodeBootstrap.register(into: r)) { error in
            XCTAssertTrue(error is ErrorCodeRegistry.CollisionError,
                          "double-bootstrap of the same registry must throw CollisionError; got \(error)")
        }
    }
}
