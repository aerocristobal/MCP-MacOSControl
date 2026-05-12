import XCTest
import MCP
@testable import MacOSControlLib

/// STORY-011 catalog-level audits. Each test iterates `ToolRouter.allTools` and
/// asserts a structural invariant on every registered tool's annotations or
/// description. These are metadata tests — they do not exercise tool behavior.
final class ToolCatalogAuditTests: XCTestCase {

    private var allTools: [Tool] { ToolRouter.allTools }

    // MARK: - Scenario: every tool has annotations populated

    func test_everyRegisteredTool_hasAnnotationsPopulated() {
        for tool in allTools {
            XCTAssertFalse(
                tool.annotations.isEmpty,
                "\(tool.name) ships with empty Tool.Annotations — STORY-011 requires explicit hints."
            )
        }
    }

    func test_everyTool_hasReadOnlyAndDestructiveHintsSet() {
        for tool in allTools {
            XCTAssertNotNil(
                tool.annotations.readOnlyHint,
                "\(tool.name) is missing readOnlyHint"
            )
            XCTAssertNotNil(
                tool.annotations.destructiveHint,
                "\(tool.name) is missing destructiveHint"
            )
        }
    }

    // MARK: - Scenario: description quality

    func test_everyToolDescription_isAtLeast50Chars() {
        for tool in allTools {
            let length = tool.description?.count ?? 0
            XCTAssertGreaterThanOrEqual(
                length, 50,
                "\(tool.name) description is \(length) chars (< 50) — re-write to include what / when / returns."
            )
        }
    }

    func test_everyToolDescription_hasNoPlaceholderText() {
        let placeholders = ["TODO", "FIXME", "XXX", "placeholder", "Description"]
        for tool in allTools {
            guard let description = tool.description else { continue }
            for placeholder in placeholders {
                XCTAssertFalse(
                    description.contains(placeholder),
                    "\(tool.name) description contains placeholder '\(placeholder)'"
                )
            }
        }
    }

    // MARK: - Scenario: read-only narrative for accessibility_tree

    func test_accessibilityTree_descriptionMentionsReadOnlyBehavior() {
        guard let tool = allTools.first(where: { $0.name == "accessibility_tree" }) else {
            XCTFail("accessibility_tree not registered")
            return
        }
        let description = tool.description ?? ""
        XCTAssertTrue(
            description.localizedCaseInsensitiveContains("read")
                || description.contains("READ-ONLY")
                || description.localizedCaseInsensitiveContains("does not modify")
                || description.localizedCaseInsensitiveContains("does NOT work"),
            "accessibility_tree description should describe its read-only nature: \(description)"
        )
    }

    // MARK: - Scenario: destructive narrative for run_applescript

    func test_runAppleScript_descriptionWarnsAboutSystemModification() {
        guard let tool = allTools.first(where: { $0.name == "run_applescript" }) else {
            XCTFail("run_applescript not registered")
            return
        }
        let description = tool.description ?? ""
        XCTAssertTrue(
            description.contains("SECURITY")
                || description.contains("DESTRUCTIVE")
                || description.localizedCaseInsensitiveContains("audit")
                || description.localizedCaseInsensitiveContains("automation"),
            "run_applescript description should warn about modification potential: \(description)"
        )
    }
}
