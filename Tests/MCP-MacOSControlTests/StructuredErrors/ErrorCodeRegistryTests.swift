// STORY: STORY-016 — Structured Error Response Contract
// COMPONENT: ErrorCodeRegistry

import XCTest
@testable import MacOSControlLib

final class ErrorCodeRegistryTests: XCTestCase {

    var registry: ErrorCodeRegistry!

    override func setUp() {
        super.setUp()
        // Use a FRESH registry for these tests so collision assertions don't
        // collide with the lazy-bootstrapped .shared instance.
        registry = ErrorCodeRegistry()
    }

    // MARK: - Scenario 2: Code naming validation

    func test_register_rejectsUppercaseCode() {
        XCTAssertThrowsError(try registry.register(
            code: "PERMISSION_DENIED",
            description: "..."
        )) { error in
            XCTAssertTrue(error is ErrorCodeRegistry.InvalidCodeError,
                          "expected InvalidCodeError, got \(error)")
        }
    }

    func test_register_rejectsCodeWithDash() {
        XCTAssertThrowsError(try registry.register(
            code: "permission-denied",
            description: "..."
        ))
    }

    func test_register_rejectsCodeStartingWithDigit() {
        XCTAssertThrowsError(try registry.register(
            code: "1_invalid",
            description: "..."
        ))
    }

    func test_register_rejectsEmptyCode() {
        XCTAssertThrowsError(try registry.register(code: "", description: "..."))
    }

    func test_register_acceptsValidSnakeCaseCode() {
        XCTAssertNoThrow(try registry.register(
            code: "permission_denied",
            description: "Accessibility permission required",
            detailsSchema: ["recovery_hint": "string"]
        ))
        XCTAssertTrue(registry.isRegistered("permission_denied"))
    }

    func test_register_acceptsCodeAtMaxLength() {
        let maxLen = String(repeating: "a", count: 64)
        XCTAssertNoThrow(try registry.register(code: maxLen, description: "..."))
    }

    func test_register_rejectsCodeLongerThan64Chars() {
        let tooLong = String(repeating: "a", count: 65)
        XCTAssertThrowsError(try registry.register(code: tooLong, description: "..."))
    }

    // MARK: - Scenario 5: Collision detection

    func test_register_throwsCollisionError_whenCodeAlreadyRegistered() throws {
        try registry.register(code: "not_found", description: "First registration")
        XCTAssertThrowsError(try registry.register(
            code: "not_found",
            description: "Second registration with conflicting semantics"
        )) { error in
            guard let collision = error as? ErrorCodeRegistry.CollisionError else {
                return XCTFail("expected CollisionError, got \(error)")
            }
            XCTAssertEqual(collision.code, "not_found")
        }
    }

    func test_collisionError_surfacesBothRegistrationCallSites() throws {
        try registry.register(code: "not_found", description: "first", callSite: "FirstTool.swift:10")
        do {
            try registry.register(code: "not_found", description: "second", callSite: "SecondTool.swift:20")
            XCTFail("expected throw")
        } catch let collision as ErrorCodeRegistry.CollisionError {
            XCTAssertEqual(collision.firstRegistrationCallSite, "FirstTool.swift:10")
            XCTAssertEqual(collision.secondRegistrationCallSite, "SecondTool.swift:20")
        }
    }

    // MARK: - Registry retrieval

    func test_registration_returnsNil_forUnregisteredCode() {
        XCTAssertNil(registry.registration(for: "never_registered"))
    }

    func test_allRegistrations_returnsCodesSorted() throws {
        try registry.register(code: "zebra_error", description: "z")
        try registry.register(code: "alpha_error", description: "a")
        try registry.register(code: "mike_error", description: "m")
        let codes = registry.allRegistrations().map { $0.code }
        XCTAssertEqual(codes, ["alpha_error", "mike_error", "zebra_error"])
    }

    func test_reset_clearsAllRegistrations() throws {
        try registry.register(code: "transient", description: "t")
        XCTAssertEqual(registry.allRegistrations().count, 1)
        registry.reset()
        XCTAssertEqual(registry.allRegistrations().count, 0)
    }
}
