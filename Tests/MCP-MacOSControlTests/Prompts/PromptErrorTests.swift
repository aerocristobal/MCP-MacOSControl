import XCTest
@testable import MacOSControlLib

final class PromptErrorTests: XCTestCase {

    // The Server.swift prompts/get handler is the production caller of these
    // properties — verify the mapping here so a future code-change can't
    // silently break the structured-error envelope.

    func test_missingRequiredArgument_mapsToCode_andCarriesArgumentInDetails() {
        let error = PromptError.missingRequiredArgument(name: "target_description")
        XCTAssertEqual(error.code, "missing_required_argument")
        XCTAssertTrue(error.message.contains("target_description"))
        XCTAssertEqual(error.details?["argument"] as? String, "target_description")
    }

    func test_unknownPlaceholder_mapsToMissingArgumentCode_andCarriesNameInDetails() {
        let error = PromptError.unknownPlaceholder(name: "stale_var")
        XCTAssertEqual(error.code, "missing_required_argument")
        XCTAssertTrue(error.message.contains("stale_var"))
        XCTAssertEqual(error.details?["argument"] as? String, "stale_var")
    }

    func test_promptNotFound_mapsToCode_andCarriesAvailableNamesInDetails() {
        let error = PromptError.promptNotFound(
            name: "missing",
            availableNames: ["a", "b", "c"]
        )
        XCTAssertEqual(error.code, "prompt_not_found")
        XCTAssertTrue(error.message.contains("missing"))
        XCTAssertEqual(error.details?["available"] as? [String], ["a", "b", "c"])
    }
}
