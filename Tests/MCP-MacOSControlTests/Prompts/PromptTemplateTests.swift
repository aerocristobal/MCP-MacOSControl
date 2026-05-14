import XCTest
@testable import MacOSControlLib

final class PromptTemplateTests: XCTestCase {

    // MARK: - Argument Substitution (Scenario 4)

    func test_resolve_substitutesNamedPlaceholder() throws {
        let template = PromptTemplate(
            content: "Click {target_description} and verify {expected_state}.",
            arguments: [
                .init(name: "target_description", required: true),
                .init(name: "expected_state", required: true)
            ]
        )
        let resolved = try template.resolve(arguments: [
            "target_description": "the Save button",
            "expected_state": "the document is saved"
        ])
        XCTAssertEqual(resolved, "Click the Save button and verify the document is saved.")
    }

    func test_resolve_leavesNoUnsubstitutedPlaceholders() throws {
        let template = PromptTemplate(
            content: "Click {target}.",
            arguments: [.init(name: "target", required: true)]
        )
        let resolved = try template.resolve(arguments: ["target": "Save"])
        XCTAssertFalse(resolved.contains("{"))
    }

    func test_resolve_handlesArgumentWithSpecialChars() throws {
        let template = PromptTemplate(
            content: "Type {text}.",
            arguments: [.init(name: "text", required: true)]
        )
        let resolved = try template.resolve(arguments: ["text": "Hello, \"world\" — done."])
        XCTAssertEqual(resolved, "Type Hello, \"world\" — done..")
    }

    // MARK: - Missing Required Argument (Scenario 5)

    func test_resolve_throwsMissingRequiredArgument_whenRequiredArgAbsent() {
        let template = PromptTemplate(
            content: "Click {target}.",
            arguments: [.init(name: "target", required: true)]
        )
        XCTAssertThrowsError(try template.resolve(arguments: [:])) { error in
            guard case PromptError.missingRequiredArgument(let name) = error else {
                return XCTFail("Expected .missingRequiredArgument, got \(error)")
            }
            XCTAssertEqual(name, "target")
        }
    }

    func test_resolve_succeeds_whenOptionalArgumentAbsent() throws {
        let template = PromptTemplate(
            content: "Click {target}{optional_suffix}.",
            arguments: [
                .init(name: "target", required: true),
                .init(name: "optional_suffix", required: false)
            ]
        )
        let resolved = try template.resolve(arguments: ["target": "Save"])
        XCTAssertEqual(resolved, "Click Save.")
    }

    // MARK: - Unknown Placeholder (defensive)

    func test_resolve_throwsUnknownPlaceholder_whenContentReferencesUnregisteredName() {
        let template = PromptTemplate(
            content: "Click {unregistered_name}.",
            arguments: [.init(name: "target", required: true)]
        )
        XCTAssertThrowsError(try template.resolve(arguments: ["target": "Save"])) { error in
            guard case PromptError.unknownPlaceholder(let name) = error else {
                return XCTFail("Expected .unknownPlaceholder, got \(error)")
            }
            XCTAssertEqual(name, "unregistered_name")
        }
    }
}
