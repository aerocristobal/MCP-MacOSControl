// STORY-014 — Find Elements by Query
// COMPONENT: ElementPredicate

import XCTest
@testable import MacOSControlLib

final class ElementPredicateTests: XCTestCase {

    // MARK: - Helpers

    private func ref(
        role: String? = nil,
        title: String? = nil,
        identifier: String? = nil,
        label: String? = nil,
        description: String? = nil
    ) -> AXElementReference {
        AXElementReference(
            role: role,
            title: title,
            identifier: identifier,
            label: label,
            description: description,
            handle: .mock(UUID())
        )
    }

    // MARK: - Validation (Scenario 6)

    func test_compile_throwsPredicateTooBroad_whenNoCriteriaSet() {
        XCTAssertThrowsError(try ElementPredicate.compile(from: FindElementsInput())) { error in
            guard case FindElementsError.predicateTooBroad = error else {
                return XCTFail("Expected .predicateTooBroad, got \(error)")
            }
        }
    }

    func test_compile_succeeds_whenOnlyRoleSet() {
        XCTAssertNoThrow(try ElementPredicate.compile(from: FindElementsInput(role: "AXButton")))
    }

    func test_compile_succeeds_whenOnlyTitleContainsSet() {
        XCTAssertNoThrow(try ElementPredicate.compile(from: FindElementsInput(titleContains: "Save")))
    }

    func test_compile_succeeds_whenOnlyDescriptionSet() {
        XCTAssertNoThrow(try ElementPredicate.compile(from: FindElementsInput(description: "Saves the file")))
    }

    // MARK: - Conflict Validation (DoD §9)

    func test_compile_throwsConflict_whenTitleAndTitleContainsBothSet() {
        let input = FindElementsInput(title: "Save", titleContains: "Sav")
        XCTAssertThrowsError(try ElementPredicate.compile(from: input)) { error in
            guard case FindElementsError.conflictingTitlePredicates = error else {
                return XCTFail("Expected .conflictingTitlePredicates, got \(error)")
            }
        }
    }

    func test_compile_throwsConflict_whenTitleAndTitleMatchesBothSet() {
        let input = FindElementsInput(title: "Save", titleMatches: "Sa.*")
        XCTAssertThrowsError(try ElementPredicate.compile(from: input)) { error in
            guard case FindElementsError.conflictingTitlePredicates = error else {
                return XCTFail("Expected .conflictingTitlePredicates, got \(error)")
            }
        }
    }

    func test_compile_throwsConflict_whenTitleContainsAndTitleMatchesBothSet() {
        let input = FindElementsInput(titleContains: "Sav", titleMatches: "Sa.*")
        XCTAssertThrowsError(try ElementPredicate.compile(from: input)) { error in
            guard case FindElementsError.conflictingTitlePredicates = error else {
                return XCTFail("Expected .conflictingTitlePredicates, got \(error)")
            }
        }
    }

    func test_compile_throwsConflict_whenIdentifierAndIdentifierMatchesBothSet() {
        let input = FindElementsInput(identifier: "save", identifierMatches: "save.*")
        XCTAssertThrowsError(try ElementPredicate.compile(from: input)) { error in
            guard case FindElementsError.conflictingIdentifierPredicates = error else {
                return XCTFail("Expected .conflictingIdentifierPredicates, got \(error)")
            }
        }
    }

    // MARK: - Identifier Matching (Scenario 2)

    func test_matches_byExactIdentifier() throws {
        let predicate = try ElementPredicate.compile(from: FindElementsInput(identifier: "save-button"))
        XCTAssertTrue(predicate.matches(ref(role: "AXButton", identifier: "save-button")))
    }

    func test_matches_rejectsDifferentIdentifier_whenExactSpecified() throws {
        let predicate = try ElementPredicate.compile(from: FindElementsInput(identifier: "save-button"))
        XCTAssertFalse(predicate.matches(ref(role: "AXButton", identifier: "cancel-button")))
    }

    func test_matches_rejectsPartialIdentifier_whenExactSpecified() throws {
        // "save" must not match "save-button" — the exact field requires equality.
        let predicate = try ElementPredicate.compile(from: FindElementsInput(identifier: "save"))
        XCTAssertFalse(predicate.matches(ref(role: "AXButton", identifier: "save-button")))
    }

    func test_matches_byIdentifierRegex() throws {
        let predicate = try ElementPredicate.compile(from: FindElementsInput(identifierMatches: "^save-.*"))
        XCTAssertTrue(predicate.matches(ref(identifier: "save-button")))
        XCTAssertFalse(predicate.matches(ref(identifier: "cancel-button")))
    }

    // MARK: - Title Matching (Scenario 1)

    func test_matches_byTitleContainsSubstring() throws {
        let predicate = try ElementPredicate.compile(from: FindElementsInput(titleContains: "old"))
        XCTAssertTrue(predicate.matches(ref(role: "AXButton", title: "Bold")))
        XCTAssertTrue(predicate.matches(ref(role: "AXButton", title: "Old File")))
        XCTAssertFalse(predicate.matches(ref(role: "AXButton", title: "New")))
    }

    func test_matches_byExactTitle() throws {
        let predicate = try ElementPredicate.compile(from: FindElementsInput(title: "Bold"))
        XCTAssertTrue(predicate.matches(ref(title: "Bold")))
        XCTAssertFalse(predicate.matches(ref(title: "Boldness")))
        XCTAssertFalse(predicate.matches(ref(title: "bold")))
    }

    func test_matches_byTitleRegex() throws {
        let predicate = try ElementPredicate.compile(from: FindElementsInput(titleMatches: "^Save( as)?$"))
        XCTAssertTrue(predicate.matches(ref(title: "Save")))
        XCTAssertTrue(predicate.matches(ref(title: "Save as")))
        XCTAssertFalse(predicate.matches(ref(title: "Save File")))
    }

    func test_matches_rejectsWhenTitleAbsent_andTitleCriterionSet() throws {
        let predicate = try ElementPredicate.compile(from: FindElementsInput(titleContains: "Save"))
        XCTAssertFalse(predicate.matches(ref(role: "AXGroup", title: nil)))
    }

    // MARK: - AND Semantics (Scenario 1)

    func test_matches_requiresAllCriteriaToMatch() throws {
        let predicate = try ElementPredicate.compile(from: FindElementsInput(role: "AXButton", titleContains: "Save"))
        XCTAssertTrue(predicate.matches(ref(role: "AXButton", title: "Save")))
        XCTAssertFalse(predicate.matches(ref(role: "AXMenuItem", title: "Save")), "wrong role must reject")
        XCTAssertFalse(predicate.matches(ref(role: "AXButton", title: "Bold")), "title not containing Save must reject")
    }

    // MARK: - Label and Description Matching

    func test_matches_byExactLabel() throws {
        let predicate = try ElementPredicate.compile(from: FindElementsInput(label: "Submit"))
        XCTAssertTrue(predicate.matches(ref(label: "Submit")))
        XCTAssertFalse(predicate.matches(ref(label: "Submit Form")))
    }

    func test_matches_byExactDescription() throws {
        let predicate = try ElementPredicate.compile(from: FindElementsInput(description: "Save the file"))
        XCTAssertTrue(predicate.matches(ref(description: "Save the file")))
        XCTAssertFalse(predicate.matches(ref(description: "Save")))
    }

    // MARK: - Regex Compilation (Scenario 7)

    func test_compile_throwsInvalidRegex_withFieldName_whenTitleMatchesIsMalformed() {
        let input = FindElementsInput(titleMatches: "[unclosed")
        XCTAssertThrowsError(try ElementPredicate.compile(from: input)) { error in
            guard case FindElementsError.invalidRegex(let field, _) = error else {
                return XCTFail("Expected .invalidRegex, got \(error)")
            }
            XCTAssertEqual(field, "title_matches")
        }
    }

    func test_compile_throwsInvalidRegex_withFieldName_whenIdentifierMatchesIsMalformed() {
        let input = FindElementsInput(identifierMatches: "(unclosed")
        XCTAssertThrowsError(try ElementPredicate.compile(from: input)) { error in
            guard case FindElementsError.invalidRegex(let field, _) = error else {
                return XCTFail("Expected .invalidRegex, got \(error)")
            }
            XCTAssertEqual(field, "identifier_matches")
        }
    }
}
