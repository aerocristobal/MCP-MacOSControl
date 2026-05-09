// STORY-002 — Semantic Element Click Tool
// COMPONENT: ClickElementTool

import XCTest
import MCP
@testable import MacOSControlLib

final class ClickElementToolTests: XCTestCase {

    var resolverSpy: AXElementResolverSpy!
    var interactorSpy: AXElementInteractorSpy!
    var bridgeStub: MockAXApplicationBridge!
    var tool: ClickElementTool!

    override func setUp() {
        super.setUp()
        resolverSpy = AXElementResolverSpy()
        interactorSpy = AXElementInteractorSpy()
        bridgeStub = MockAXApplicationBridge()
        tool = ClickElementTool(
            resolver: resolverSpy,
            interactor: interactorSpy,
            bridge: bridgeStub
        )
    }

    // MARK: - Scenario 1: Happy Path — click button by title

    func test_execute_callsResolverWithProvidedRoleAndTitle() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXButton", title: "Bold", identifier: "ax-bold-1"
        )
        let params = makeParams(name: "click_element", args: [
            "title": .string("Bold"),
            "role":  .string("AXButton")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(resolverSpy.lastTitle, "Bold")
        XCTAssertEqual(resolverSpy.lastRole, "AXButton")
    }

    func test_execute_dispatchesAXPressOnResolvedElement() async throws {
        let element = AXElementReference.mockReference(role: "AXButton", title: "Bold")
        resolverSpy.stubbedResult = element
        let params = makeParams(name: "click_element", args: [
            "title": .string("Bold")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(interactorSpy.pressCallCount, 1)
        XCTAssertEqual(interactorSpy.lastPressedElement?.title, "Bold")
    }

    func test_execute_responseIncludesAXIdentifier() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXButton", title: "Bold", identifier: "ax-bold-1"
        )
        let params = makeParams(name: "click_element", args: [
            "title": .string("Bold")
        ])

        let result = try await tool.execute(params)

        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("ax-bold-1"),
                      "expected response to include resolved AXIdentifier; got: \(text)")
        XCTAssertNotEqual(result?.isError, true)
    }

    // MARK: - Scenario 2: Click checkbox by label, return state

    func test_execute_passesLabelLocatorToResolver() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXCheckBox", label: "Enable spell check"
        )
        let params = makeParams(name: "click_element", args: [
            "label": .string("Enable spell check"),
            "role":  .string("AXCheckBox")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(resolverSpy.lastLabel, "Enable spell check")
        XCTAssertEqual(resolverSpy.lastAttributeKind, .label)
        XCTAssertEqual(resolverSpy.lastAttributeValue, "Enable spell check")
    }

    func test_execute_responseIncludesPostActionState_whenReturnStateIsTrue() async throws {
        // Bridge returns a non-nil value when asked after the press.
        bridgeStub = MockAXApplicationBridge(elements: [
            MockAXUIElement(role: "AXCheckBox", label: "Enable spell check",
                            pid: 1, value: "1")
        ])
        let windows = try bridgeStub.windows(forPID: 1)
        guard let resolved = windows.first else { return XCTFail("setup failed") }
        resolverSpy.stubbedResult = resolved
        tool = ClickElementTool(
            resolver: resolverSpy,
            interactor: interactorSpy,
            bridge: bridgeStub
        )

        let params = makeParams(name: "click_element", args: [
            "label":        .string("Enable spell check"),
            "return_state": .bool(true)
        ])

        let result = try await tool.execute(params)

        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("\"value\""),
                      "expected post-action state in response; got: \(text)")
        XCTAssertTrue(text.contains("\"1\""), "expected value=1; got: \(text)")
    }

    func test_execute_doesNotIncludeValue_whenReturnStateIsFalseOrAbsent() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "Bold")
        let params = makeParams(name: "click_element", args: [
            "title": .string("Bold")
        ])

        let result = try await tool.execute(params)

        let text = extractText(from: result!) ?? ""
        XCTAssertFalse(text.contains("\"value\""),
                       "value should be omitted by default; got: \(text)")
    }

    // MARK: - Scenario 3: Element not found

    func test_execute_returnsElementNotFoundError_whenResolverThrows() async throws {
        resolverSpy.stubbedError = AXNotFoundError(searchCriteria: "title=FakeButton")
        let params = makeParams(name: "click_element", args: [
            "title": .string("FakeButton")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        // BDD Scenario 3: "error with code 'element_not_found'" + "lists the search criteria used"
        XCTAssertTrue(text.contains("element_not_found"),
                      "expected BDD error code 'element_not_found'; got: \(text)")
        XCTAssertTrue(text.contains("FakeButton"),
                      "expected error message to list search criteria; got: \(text)")
    }

    func test_execute_doesNotDispatchPress_whenResolutionFails() async throws {
        resolverSpy.stubbedError = AXNotFoundError(searchCriteria: "title=FakeButton")
        let params = makeParams(name: "click_element", args: [
            "title": .string("FakeButton")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(interactorSpy.pressCallCount, 0)
    }

    func test_execute_returnsActionError_whenInteractorThrows() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "Save")
        interactorSpy.simulatedError = AXActionError(
            code: .elementDisabled, action: "AXPress",
            detail: "element is not enabled"
        )
        let params = makeParams(name: "click_element", args: [
            "title": .string("Save")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("AX_ELEMENT_DISABLED"),
                      "expected disabled error code; got: \(text)")
    }

    // MARK: - Scenario 4: Application scope

    func test_execute_appliesBundleIdScope_whenApplicationContainsDot() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "View")
        let params = makeParams(name: "click_element", args: [
            "title":       .string("View"),
            "application": .string("com.apple.TextEdit")
        ])

        _ = try await tool.execute(params)

        guard case .bundleId(let bid)? = resolverSpy.lastScope else {
            return XCTFail("expected .bundleId scope; got \(String(describing: resolverSpy.lastScope))")
        }
        XCTAssertEqual(bid, "com.apple.TextEdit")
    }

    func test_execute_appliesNameScope_whenApplicationIsBareName() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "View")
        let params = makeParams(name: "click_element", args: [
            "title":       .string("View"),
            "application": .string("TextEdit")
        ])

        _ = try await tool.execute(params)

        guard case .name(let n)? = resolverSpy.lastScope else {
            return XCTFail("expected .name scope; got \(String(describing: resolverSpy.lastScope))")
        }
        XCTAssertEqual(n, "TextEdit")
    }

    // MARK: - Locator precedence: identifier-first dispatch

    func test_execute_dispatchesByIdentifier_whenIdentifierProvided() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXButton", title: "Bold", identifier: "ax-bold-1"
        )
        let params = makeParams(name: "click_element", args: [
            "identifier": .string("ax-bold-1"),
            "title":      .string("Bold")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(resolverSpy.lastAttributeKind, .identifier)
        XCTAssertEqual(resolverSpy.lastAttributeValue, "ax-bold-1")
    }

    func test_execute_returnsNotFound_whenIdentifierMatchButOtherLocatorsMismatch() async throws {
        // Resolver returns an element whose identifier matches, but title differs.
        resolverSpy.stubbedResult = .mockReference(
            role: "AXButton", title: "WrongTitle", identifier: "ax-bold-1"
        )
        let params = makeParams(name: "click_element", args: [
            "identifier": .string("ax-bold-1"),
            "title":      .string("Bold")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true,
                       "post-validation must reject mismatched element")
        XCTAssertEqual(interactorSpy.pressCallCount, 0)
    }

    // MARK: - Input validation

    func test_execute_rejectsWhenNoLocatorProvided() async throws {
        let params = makeParams(name: "click_element", args: [:])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.lowercased().contains("locator"),
                      "expected validation message about missing locator; got: \(text)")
        XCTAssertEqual(resolverSpy.callCount, 0)
        XCTAssertEqual(interactorSpy.pressCallCount, 0)
    }

    func test_execute_acceptsWhenAtLeastOneLocatorProvided() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "Bold")
        let params = makeParams(name: "click_element", args: [
            "title": .string("Bold")
        ])

        let result = try await tool.execute(params)

        XCTAssertNotEqual(result?.isError, true)
        XCTAssertEqual(resolverSpy.callCount, 1)
    }

    // MARK: - Locator dispatch fallbacks (description-only, role-only)

    func test_execute_dispatchesByDescription_whenOnlyDescriptionProvided() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXButton", description: "Close window"
        )
        let params = makeParams(name: "click_element", args: [
            "description": .string("Close window")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(resolverSpy.lastAttributeKind, .description)
        XCTAssertEqual(resolverSpy.lastAttributeValue, "Close window")
    }

    func test_execute_dispatchesByRole_whenOnlyRoleProvided() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton")
        let params = makeParams(name: "click_element", args: [
            "role": .string("AXButton")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(resolverSpy.lastAttributeKind, .role)
        XCTAssertEqual(resolverSpy.lastAttributeValue, "AXButton")
    }

    // MARK: - Post-validation mismatches (each attribute, AND-filter)

    func test_execute_postValidatesRoleMismatch() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXStaticText", title: "Bold", identifier: "ax-bold-1"
        )
        let params = makeParams(name: "click_element", args: [
            "identifier": .string("ax-bold-1"),
            "role":       .string("AXButton")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        XCTAssertEqual(interactorSpy.pressCallCount, 0)
    }

    func test_execute_postValidatesLabelMismatch() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXButton", title: "Bold", identifier: "ax-bold-1", label: "ActualLabel"
        )
        let params = makeParams(name: "click_element", args: [
            "identifier": .string("ax-bold-1"),
            "label":      .string("WrongLabel")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        XCTAssertEqual(interactorSpy.pressCallCount, 0)
    }

    func test_execute_postValidatesDescriptionMismatch() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXButton", identifier: "ax-bold-1", description: "ActualDesc"
        )
        let params = makeParams(name: "click_element", args: [
            "identifier":  .string("ax-bold-1"),
            "description": .string("WrongDesc")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        XCTAssertEqual(interactorSpy.pressCallCount, 0)
    }

    // MARK: - AXResolutionError pass-through

    func test_execute_returnsResolutionError_whenResolverThrowsAXResolutionError() async throws {
        resolverSpy.stubbedError = AXResolutionError(
            detail: "search exceeded timeout", underlyingCode: -25204
        )
        let params = makeParams(name: "click_element", args: [
            "title": .string("Bold")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("AX_RESOLUTION_FAILED"),
                      "expected resolution error code; got: \(text)")
        XCTAssertEqual(interactorSpy.pressCallCount, 0)
    }
}
