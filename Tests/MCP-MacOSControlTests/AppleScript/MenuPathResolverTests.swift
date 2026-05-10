// STORY-007 — click_menu_item MCP Tool
// COMPONENT: MenuPathResolver

import XCTest
@testable import MacOSControlLib

final class MenuPathResolverTests: XCTestCase {

    var resolver: MenuPathResolver!

    override func setUp() {
        super.setUp()
        resolver = MenuPathResolver()
    }

    // MARK: - Click script generation

    func test_script_generatesTwoLevelPath() {
        let script = resolver.script(for: ["File", "Save"], application: "TextEdit")

        XCTAssertTrue(script.contains("\"TextEdit\""))
        XCTAssertTrue(script.contains("menu item \"Save\""))
        XCTAssertTrue(script.contains("menu bar item \"File\""))
        XCTAssertTrue(script.contains("menu \"File\""))
    }

    func test_script_generatesThreeLevelNestedPath() {
        let script = resolver.script(for: ["Format", "Font", "Bold"],
                                     application: "TextEdit")

        XCTAssertTrue(script.contains("menu item \"Bold\""))
        XCTAssertTrue(script.contains("menu \"Font\""))
        XCTAssertTrue(script.contains("menu item \"Font\""),
                      "intermediate component must appear as both `menu` and `menu item`")
        XCTAssertTrue(script.contains("menu bar item \"Format\""))
    }

    func test_script_quotesApplicationNameCorrectly() {
        let script = resolver.script(for: ["File", "Save"],
                                     application: "Microsoft Word")

        XCTAssertTrue(script.contains("\"Microsoft Word\""))
    }

    func test_script_escapesQuotesInMenuItemNames() {
        let script = resolver.script(for: ["File", "Open \"Recent\""],
                                     application: "TextEdit")

        // AppleScript escape is backslash-quote — generated source must escape correctly.
        XCTAssertTrue(script.contains("\\\"Recent\\\""))
    }

    func test_script_includesActivationByDefault() {
        let script = resolver.script(for: ["File", "Save"], application: "TextEdit")
        XCTAssertTrue(script.contains("tell application \"TextEdit\" to activate"))
    }

    func test_script_omitsActivation_whenDoNotActivateIsTrue() {
        let script = resolver.script(for: ["File", "Save"],
                                     application: "TextEdit",
                                     doNotActivate: true)
        XCTAssertFalse(script.contains("tell application \"TextEdit\" to activate"))
    }

    func test_script_includesEnabledCheck() {
        let script = resolver.script(for: ["Edit", "Cut"], application: "TextEdit")
        XCTAssertTrue(script.contains("enabled of targetItem is false"))
        XCTAssertTrue(script.contains("(item is disabled)"))
        XCTAssertTrue(script.contains("number -1728"))
    }

    // MARK: - Alternatives script generation (path-not-found path)

    func test_alternativesScript_returnsEnumerationOfFailingLevel() {
        let enumScript = resolver.alternativesScript(for: ["File", "NonExistent"],
                                                     application: "TextEdit")

        XCTAssertTrue(enumScript.contains("name of every menu item"))
        XCTAssertTrue(enumScript.contains("menu \"File\""))
        XCTAssertTrue(enumScript.contains("menu bar item \"File\""))
    }

    func test_alternativesScript_threeLevelPathEnumeratesIntermediateMenu() {
        let enumScript = resolver.alternativesScript(for: ["Format", "Font", "MissingLeaf"],
                                                     application: "TextEdit")

        XCTAssertTrue(enumScript.contains("name of every menu item"))
        XCTAssertTrue(enumScript.contains("menu \"Font\""))
        XCTAssertTrue(enumScript.contains("menu item \"Font\""))
    }

    func test_alternativesScript_singleElementPathEnumeratesMenuBar() {
        let enumScript = resolver.alternativesScript(for: ["BogusTopLevel"],
                                                     application: "TextEdit")

        XCTAssertTrue(enumScript.contains("name of every menu bar item"))
        XCTAssertTrue(enumScript.contains("menu bar 1"))
    }

    // MARK: - Defensive: hostile menu names cannot inject AppleScript directives

    func test_script_neutralizesHostileMenuNames() {
        // A malicious caller passes a menu name that, if not escaped, would close the
        // current string literal and embed a `do shell script` command.
        let hostile = "Save\"; do shell script \"rm -rf /\"; \""
        let script = resolver.script(for: ["File", hostile], application: "TextEdit")

        // Each `"` inside the name must be escaped as `\"` in the AppleScript source.
        // Verify that the dangerous suffix appears only in escaped form (preceded by `\`)
        // and never as a live directive.
        let dangerousLiveDirective = "; do shell script \"rm -rf /\""
        XCTAssertFalse(script.contains(dangerousLiveDirective),
                       "an unescaped `do shell script` directive must never appear in generated source")

        // The escaped form should appear at least once.
        XCTAssertTrue(script.contains("\\\"; do shell script \\\"rm -rf /\\\""),
                      "hostile substring must be embedded as an escaped AppleScript string literal")
    }
}
