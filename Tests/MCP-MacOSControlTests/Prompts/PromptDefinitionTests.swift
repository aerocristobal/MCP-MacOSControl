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

    func test_parse_throwsMissingFrontMatter_whenSourceHasNoDelimiters() {
        let source = "Just a body, no front matter at all."
        XCTAssertThrowsError(try PromptDefinition.parse(source)) { error in
            guard case PromptDefinition.LoadError.missingFrontMatter = error else {
                return XCTFail("Expected .missingFrontMatter, got \(error)")
            }
        }
    }

    func test_parse_throwsInvalidPromptVersion_whenVersionIsNotAnInteger() {
        let source = """
        ---
        name: bad
        description: A prompt whose prompt_version is not an integer should fail to load.
        prompt_version: not-a-number
        ---
        body
        """
        XCTAssertThrowsError(try PromptDefinition.parse(source)) { error in
            guard case PromptDefinition.LoadError.invalidPromptVersion = error else {
                return XCTFail("Expected .invalidPromptVersion, got \(error)")
            }
        }
    }

    func test_parse_throwsMissingName_whenNameKeyAbsent() {
        let source = """
        ---
        description: A prompt missing its name key should fail to load with a clear error.
        prompt_version: 1
        ---
        body
        """
        XCTAssertThrowsError(try PromptDefinition.parse(source)) { error in
            guard case PromptDefinition.LoadError.missingKey(let key) = error else {
                return XCTFail("Expected .missingKey, got \(error)")
            }
            XCTAssertEqual(key, "name")
        }
    }

    func test_parse_handlesQuotedScalarValuesAndStripsQuotes() throws {
        let source = """
        ---
        name: quoted
        description: "A description containing: a colon that requires quoting under YAML rules."
        prompt_version: 1
        arguments: []
        ---
        body
        """
        let definition = try PromptDefinition.parse(source)
        XCTAssertEqual(definition.name, "quoted")
        XCTAssertTrue(definition.description.contains("requires quoting"))
        XCTAssertFalse(definition.description.hasPrefix("\""))
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
