import XCTest
@testable import MacOSControlLib

final class PromptDefinitionTests: XCTestCase {

    // MARK: - Front Matter Parsing (Scenario 7)

    func test_parse_loadsNameDescriptionAndPromptVersionFromFrontMatter() throws {
        let source = """
        ---
        name: interaction_hierarchy
        description: Recommended order for choosing UI interaction layers (AX → AppleScript → hit-test → coordinate)
        prompt_version: 1
        arguments: []
        ---
        When you need to interact with a macOS UI element, prefer the layers in this order...
        """
        let definition = try PromptDefinition.parse(source)
        XCTAssertEqual(definition.name, "interaction_hierarchy")
        XCTAssertEqual(definition.promptVersion, 1)
        XCTAssertGreaterThanOrEqual(definition.description.count, 50)
        XCTAssertTrue(definition.body.hasPrefix("When you need"))
    }

    func test_parse_throwsLoadTimeError_whenPromptVersionMissing() {
        let source = """
        ---
        name: interaction_hierarchy
        description: Recommended order for choosing UI interaction layers
        ---
        Body
        """
        XCTAssertThrowsError(try PromptDefinition.parse(source)) { error in
            guard case PromptDefinition.LoadError.missingKey(let key) = error else {
                return XCTFail("Expected LoadError.missingKey, got \(error)")
            }
            XCTAssertEqual(key, "prompt_version")
        }
    }

    func test_parse_loadsArgumentDeclarations() throws {
        let source = """
        ---
        name: click_and_verify
        description: Workflow: click a target element and verify a state condition holds afterward
        prompt_version: 1
        arguments:
          - name: target_description
            required: true
          - name: expected_state
            required: true
        ---
        Click {target_description}, then confirm {expected_state}.
        """
        let definition = try PromptDefinition.parse(source)
        XCTAssertEqual(definition.arguments.count, 2)
        XCTAssertEqual(definition.arguments[0].name, "target_description")
        XCTAssertTrue(definition.arguments[0].required)
        XCTAssertEqual(definition.arguments[1].name, "expected_state")
        XCTAssertTrue(definition.arguments[1].required)
    }
}
