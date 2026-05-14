import XCTest
import MCP
@testable import MacOSControlLib

final class PromptRegistryTests: XCTestCase {

    var registry: PromptRegistry!

    override func setUp() {
        super.setUp()
        // Loading the bundled definitions exercises the markdown loader end-to-end.
        registry = try! PromptRegistry.standardRegistry()
    }

    // MARK: - List (Scenario 1)

    func test_list_includesAllThreeBundledPrompts() {
        let names = Set(registry.list().map(\.name))
        XCTAssertTrue(names.contains("interaction_hierarchy"))
        XCTAssertTrue(names.contains("macos_permissions_checklist"))
        XCTAssertTrue(names.contains("click_and_verify"))
    }

    func test_list_eachPromptHasDescriptionAtLeast50Chars() {
        for prompt in registry.list() {
            let description = prompt.description ?? ""
            XCTAssertGreaterThanOrEqual(
                description.count, 50,
                "\(prompt.name) description is too short — must explain when to use the prompt"
            )
        }
    }

    // MARK: - Versioning (Scenario 7 — metadata side)

    func test_list_eachPromptCarriesPromptVersionInMetadata() {
        for prompt in registry.list() {
            guard let meta = prompt._meta else {
                XCTFail("\(prompt.name) is missing _meta entirely")
                continue
            }
            guard let value = meta.fields["prompt_version"] else {
                XCTFail("\(prompt.name) _meta does not include prompt_version")
                continue
            }
            if case .int(let version) = value {
                XCTAssertGreaterThanOrEqual(version, 1)
            } else {
                XCTFail("\(prompt.name) prompt_version is not an int: \(value)")
            }
        }
    }

    // MARK: - Get Static Prompt (Scenarios 2, 3)

    func test_get_interactionHierarchy_namesAllFourLayers() throws {
        let resolved = try registry.get(name: "interaction_hierarchy", arguments: [:])
        let body = Self.joinedText(resolved.messages)
        XCTAssertTrue(body.contains("AX semantic"), "Prompt must name the AX semantic layer")
        XCTAssertTrue(body.contains("AppleScript"), "Prompt must name the AppleScript layer")
        XCTAssertTrue(body.contains("hit-test") || body.contains("element_at_position"),
                       "Prompt must name the hit-test layer")
        XCTAssertTrue(body.lowercased().contains("coordinate"), "Prompt must name the coordinate fallback layer")
        XCTAssertTrue(body.contains("click_element"))
        XCTAssertTrue(body.contains("run_applescript"))
        XCTAssertTrue(body.contains("element_at_position"))
        XCTAssertTrue(body.contains("click_screen"))
    }

    func test_get_interactionHierarchy_isUserRoleMessage() throws {
        let resolved = try registry.get(name: "interaction_hierarchy", arguments: [:])
        XCTAssertFalse(resolved.messages.isEmpty)
        XCTAssertEqual(resolved.messages.first?.role, .user)
    }

    func test_get_permissionsChecklist_describesAllThreePermissions() throws {
        // Locked design deviation from story Scenario 3: this server has no tools
        // that require Input Monitoring, so the checklist covers the three
        // permissions the server actually uses.
        let resolved = try registry.get(name: "macos_permissions_checklist", arguments: [:])
        let body = Self.joinedText(resolved.messages)
        XCTAssertTrue(body.contains("Accessibility"))
        XCTAssertTrue(body.contains("Screen Recording"))
        XCTAssertTrue(body.contains("Automation"))
        XCTAssertTrue(body.contains("Privacy_Accessibility"),
                       "Prompt must include the Accessibility System Settings deep link")
        XCTAssertTrue(body.contains("Privacy_ScreenCapture"),
                       "Prompt must include the Screen Recording System Settings deep link")
        XCTAssertTrue(body.contains("Privacy_Automation"),
                       "Prompt must include the Automation System Settings deep link")
    }

    // MARK: - Get Parameterized Prompt (Scenario 4)

    func test_get_clickAndVerify_substitutesArguments() throws {
        let resolved = try registry.get(
            name: "click_and_verify",
            arguments: [
                "target_description": "the Save button",
                "expected_state": "the document is saved"
            ]
        )
        let body = Self.joinedText(resolved.messages)
        XCTAssertTrue(body.contains("the Save button"))
        XCTAssertTrue(body.contains("the document is saved"))
        XCTAssertFalse(body.contains("{target_description}"))
        XCTAssertFalse(body.contains("{expected_state}"))
    }

    // MARK: - Errors (Scenarios 5, 6)

    func test_get_throwsMissingRequiredArgument_whenArgumentAbsent() {
        XCTAssertThrowsError(try registry.get(name: "click_and_verify", arguments: [:])) { error in
            guard case PromptError.missingRequiredArgument(let name) = error else {
                return XCTFail("Expected .missingRequiredArgument, got \(error)")
            }
            XCTAssertFalse(name.isEmpty)
        }
    }

    func test_get_throwsPromptNotFound_whenNameUnregistered() {
        XCTAssertThrowsError(try registry.get(name: "no_such_prompt", arguments: [:])) { error in
            guard case PromptError.promptNotFound(let name, let availableNames) = error else {
                return XCTFail("Expected .promptNotFound, got \(error)")
            }
            XCTAssertEqual(name, "no_such_prompt")
            XCTAssertFalse(availableNames.isEmpty,
                            "promptNotFound error must list available prompt names")
            XCTAssertTrue(availableNames.contains("interaction_hierarchy"))
        }
    }

    // MARK: - Helpers

    private static func joinedText(_ messages: [Prompt.Message]) -> String {
        messages.compactMap { message in
            if case .text(let text) = message.content { return text }
            return nil
        }
        .joined(separator: "\n")
    }
}
