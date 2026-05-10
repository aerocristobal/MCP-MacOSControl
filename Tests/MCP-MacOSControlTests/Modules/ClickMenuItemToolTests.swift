// STORY-007 — click_menu_item MCP Tool
// COMPONENT: ClickMenuItemTool

import XCTest
import MCP
@testable import MacOSControlLib

final class ClickMenuItemToolTests: XCTestCase {

    var backendSpy: MenuClickBackendSpy!
    var tool: ClickMenuItemTool!

    override func setUp() {
        super.setUp()
        backendSpy = MenuClickBackendSpy()
        tool = ClickMenuItemTool(backend: backendSpy,
                                 normalizer: MenuItemNormalizer())
    }

    // MARK: - Happy Path (Scenario 1)

    func test_execute_callsBackendWithNormalizedPath() async throws {
        backendSpy.stubbedClickResult = .success
        let params = makeParams(name: "click_menu_item",
                                args: ["application": .string("TextEdit"),
                                       "path":        .array([.string("File"),
                                                              .string("Save…")])])

        _ = try await tool.execute(params)

        XCTAssertEqual(backendSpy.lastClickPath, ["File", "Save"],
                       "trailing ellipsis should be normalized away before backend call")
        XCTAssertEqual(backendSpy.lastClickApplication, "TextEdit")
    }

    func test_execute_invokesBackendOnce_perCall() async throws {
        backendSpy.stubbedClickResult = .success
        let params = makeParams(name: "click_menu_item",
                                args: ["application": .string("TextEdit"),
                                       "path":        .array([.string("File"),
                                                              .string("Save")])])

        _ = try await tool.execute(params)

        XCTAssertEqual(backendSpy.clickCallCount, 1)
    }

    // MARK: - Alternative Path (Scenario 2)

    func test_execute_supportsThreeLevelNestedPath() async throws {
        backendSpy.stubbedClickResult = .success
        let params = makeParams(name: "click_menu_item",
                                args: ["application": .string("TextEdit"),
                                       "path":        .array([.string("Format"),
                                                              .string("Font"),
                                                              .string("Bold")])])

        let result = try await tool.execute(params)

        XCTAssertFalse(result?.isError ?? true)
        XCTAssertEqual(backendSpy.lastClickPath, ["Format", "Font", "Bold"])
    }

    // MARK: - Error Path: Disabled (Scenario 3)

    func test_execute_returnsMenuItemDisabledError_whenBackendReportsDisabled() async throws {
        backendSpy.stubbedClickResult = .disabled
        let params = makeParams(name: "click_menu_item",
                                args: ["application": .string("TextEdit"),
                                       "path":        .array([.string("Edit"),
                                                              .string("Cut")])])

        let result = try await tool.execute(params)

        XCTAssertTrue(result?.isError ?? false)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("menu_item_disabled"))
    }

    // MARK: - Error Path: Not Found (Scenario 4)

    func test_execute_returnsMenuItemNotFoundError_withAlternativesFromBackend() async throws {
        backendSpy.stubbedClickResult = .notFound
        backendSpy.stubbedAlternatives = ["New", "Open", "Save", "Save As", "Print", "Close"]
        let params = makeParams(name: "click_menu_item",
                                args: ["application": .string("TextEdit"),
                                       "path":        .array([.string("File"),
                                                              .string("NonExistentItem")])])

        let result = try await tool.execute(params)

        XCTAssertTrue(result?.isError ?? false)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("menu_item_not_found"))
        XCTAssertTrue(text.contains("Save"),
                      "alternatives at the failing level should be listed in the error")
        XCTAssertEqual(backendSpy.alternativesCallCount, 1,
                       "alternatives lookup must be invoked exactly once on not-found")
    }

    // MARK: - Input Validation

    func test_execute_rejectsEmptyPath() async throws {
        let params = makeParams(name: "click_menu_item",
                                args: ["application": .string("TextEdit"),
                                       "path":        .array([])])

        let result = try await tool.execute(params)

        XCTAssertTrue(result?.isError ?? false)
        XCTAssertEqual(backendSpy.clickCallCount, 0)
    }

    func test_execute_rejectsPathExceedingDepthLimit() async throws {
        let deepPath: [Value] = (1...8).map { .string("Level\($0)") }
        let params = makeParams(name: "click_menu_item",
                                args: ["application": .string("TextEdit"),
                                       "path":        .array(deepPath)])

        let result = try await tool.execute(params)

        XCTAssertTrue(result?.isError ?? false)
        XCTAssertEqual(backendSpy.clickCallCount, 0)
    }

    func test_execute_rejectsMissingPath() async throws {
        let params = makeParams(name: "click_menu_item",
                                args: ["application": .string("TextEdit")])

        let result = try await tool.execute(params)

        XCTAssertTrue(result?.isError ?? false)
        XCTAssertEqual(backendSpy.clickCallCount, 0)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("invalid_input"))
    }

    func test_execute_rejectsPathThatNormalizesToEmpty() async throws {
        let params = makeParams(name: "click_menu_item",
                                args: ["application": .string("TextEdit"),
                                       "path":        .array([.string("File"),
                                                              .string("   ...")])])

        let result = try await tool.execute(params)

        XCTAssertTrue(result?.isError ?? false)
        XCTAssertEqual(backendSpy.clickCallCount, 0)
    }

    func test_execute_passesDoNotActivateFlag_whenSet() async throws {
        backendSpy.stubbedClickResult = .success
        let params = makeParams(name: "click_menu_item",
                                args: ["application":     .string("TextEdit"),
                                       "path":            .array([.string("File"),
                                                                  .string("Save")]),
                                       "do_not_activate": .bool(true)])

        _ = try await tool.execute(params)

        XCTAssertEqual(backendSpy.lastDoNotActivate, true)
    }

    func test_execute_returnsExecutionTimeoutError_whenBackendThrowsTimeout() async throws {
        backendSpy.stubbedClickError = MenuClickError.timeout(after: 30)
        let params = makeParams(name: "click_menu_item",
                                args: ["application": .string("TextEdit"),
                                       "path":        .array([.string("File"),
                                                              .string("Save")])])

        let result = try await tool.execute(params)

        XCTAssertTrue(result?.isError ?? false)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("execution_timeout"))
        // Tool messages must NOT name the AppleScript backend.
        XCTAssertFalse(text.contains("osascript"))
        XCTAssertFalse(text.contains("AppleScript"))
    }

    func test_execute_returnsBackendError_whenBackendThrowsBackendFailure() async throws {
        backendSpy.stubbedClickError = MenuClickError.backendFailure(detail: "transport down")
        let params = makeParams(name: "click_menu_item",
                                args: ["application": .string("TextEdit"),
                                       "path":        .array([.string("File"),
                                                              .string("Save")])])

        let result = try await tool.execute(params)

        XCTAssertTrue(result?.isError ?? false)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("backend_error"))
        XCTAssertTrue(text.contains("transport down"))
    }

    func test_execute_defaultsDoNotActivateToFalse() async throws {
        backendSpy.stubbedClickResult = .success
        let params = makeParams(name: "click_menu_item",
                                args: ["application": .string("TextEdit"),
                                       "path":        .array([.string("File"),
                                                              .string("Save")])])

        _ = try await tool.execute(params)

        XCTAssertEqual(backendSpy.lastDoNotActivate, false)
    }
}
