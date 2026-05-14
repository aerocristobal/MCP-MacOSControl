// STORY-003 — AX Action Performer Tool
// COMPONENT: PerformAXActionTool

import XCTest
import MCP
@testable import MacOSControlLib

final class PerformAXActionToolTests: XCTestCase {

    var resolverSpy: AXElementResolverSpy!
    var interactorSpy: AXElementInteractorSpy!
    var enumeratorSpy: AXActionEnumeratorSpy!
    var bridgeStub: MockAXApplicationBridge!
    var tool: PerformAXActionTool!

    override func setUp() {
        super.setUp()
        resolverSpy = AXElementResolverSpy()
        interactorSpy = AXElementInteractorSpy()
        enumeratorSpy = AXActionEnumeratorSpy()
        bridgeStub = MockAXApplicationBridge()
        tool = PerformAXActionTool(
            resolver: resolverSpy,
            interactor: interactorSpy,
            enumerator: enumeratorSpy,
            bridge: bridgeStub
        )
    }

    // MARK: - Scenario 1: Perform AXPress on a button

    func test_execute_dispatchesAXPress_viaInteractor() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXButton", title: "OK", identifier: "ax-ok-1"
        )
        enumeratorSpy.stubbedActions = ["AXPress"]
        let params = makeParams(name: "perform_ax_action", args: [
            "title":  .string("OK"),
            "role":   .string("AXButton"),
            "action": .string("AXPress")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(interactorSpy.performCallCount, 1)
        XCTAssertEqual(interactorSpy.lastAction, "AXPress")
        XCTAssertNotEqual(result?.isError, true)
    }

    func test_execute_responseIncludesActionAndIdentifier_onSuccess() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXButton", title: "OK", identifier: "ax-ok-1"
        )
        enumeratorSpy.stubbedActions = ["AXPress"]
        let params = makeParams(name: "perform_ax_action", args: [
            "title":  .string("OK"),
            "action": .string("AXPress")
        ])

        let result = try await tool.execute(params)

        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("\"action\""), "expected action in response; got: \(text)")
        XCTAssertTrue(text.contains("AXPress"), "expected AXPress in response; got: \(text)")
        XCTAssertTrue(text.contains("ax-ok-1"), "expected identifier in response; got: \(text)")
    }

    // MARK: - Scenario 2: Perform AXShowMenu on a pop-up button

    func test_execute_dispatchesAXShowMenu_viaInteractor() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXPopUpButton", label: "Font"
        )
        enumeratorSpy.stubbedActions = ["AXShowMenu", "AXPress"]
        let params = makeParams(name: "perform_ax_action", args: [
            "label":  .string("Font"),
            "role":   .string("AXPopUpButton"),
            "action": .string("AXShowMenu")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(interactorSpy.lastAction, "AXShowMenu")
        XCTAssertEqual(interactorSpy.performCallCount, 1)
    }

    // MARK: - Scenario 3: Discovery — return supported actions when action omitted

    func test_execute_returnsActionList_whenActionOmitted() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXTextField", identifier: "search-input"
        )
        enumeratorSpy.stubbedActions = ["AXPress", "AXConfirm", "AXCancel"]
        let params = makeParams(name: "perform_ax_action", args: [
            "identifier": .string("search-input")
        ])

        let result = try await tool.execute(params)

        XCTAssertNotEqual(result?.isError, true,
                          "discovery is a success response, not an error")
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("AXPress"), "expected AXPress in discovery list; got: \(text)")
        XCTAssertTrue(text.contains("AXConfirm"), "expected AXConfirm in discovery list; got: \(text)")
        XCTAssertTrue(text.contains("supported_actions"),
                      "expected supported_actions key in response; got: \(text)")
        XCTAssertEqual(interactorSpy.performCallCount, 0,
                       "discovery path must not dispatch any action")
    }

    func test_execute_returnsActionList_whenActionIsEmptyString() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "OK")
        enumeratorSpy.stubbedActions = ["AXPress"]
        let params = makeParams(name: "perform_ax_action", args: [
            "title":  .string("OK"),
            "action": .string("")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(interactorSpy.performCallCount, 0,
                       "empty action string must be treated as omitted (discovery)")
    }

    // MARK: - Scenario 4: Unsupported action returns error with alternatives

    func test_execute_returnsActionNotSupportedError_withSupportedList() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXStaticText", title: "Version: 1.0"
        )
        enumeratorSpy.stubbedActions = []  // static text supports nothing
        let params = makeParams(name: "perform_ax_action", args: [
            "role":   .string("AXStaticText"),
            "title":  .string("Version: 1.0"),
            "action": .string("AXPress")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("action_not_supported"),
                      "expected snake_case error code; got: \(text)")
        XCTAssertTrue(text.contains("supported_actions"),
                      "expected supported_actions list in error; got: \(text)")
        XCTAssertEqual(interactorSpy.performCallCount, 0,
                       "no action must be dispatched on rejection")
    }

    func test_execute_actionNotSupportedError_includesAlternatives() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXSlider", title: "Volume")
        enumeratorSpy.stubbedActions = ["AXIncrement", "AXDecrement"]
        let params = makeParams(name: "perform_ax_action", args: [
            "title":  .string("Volume"),
            "action": .string("AXPress")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("AXIncrement"),
                      "error must list the actions the element does support; got: \(text)")
        XCTAssertTrue(text.contains("AXDecrement"),
                      "error must list the actions the element does support; got: \(text)")
    }

    // MARK: - Scenario Outline: Standard actions

    func test_execute_dispatchesEachStandardAction() async throws {
        let standardActions = ["AXPress", "AXIncrement", "AXDecrement",
                               "AXConfirm", "AXCancel", "AXShowMenu",
                               "AXRaise", "AXPick"]

        for action in standardActions {
            try await assertActionDispatches(action)
        }
    }

    private func assertActionDispatches(_ action: String) async throws {
        resolverSpy = AXElementResolverSpy()
        interactorSpy = AXElementInteractorSpy()
        enumeratorSpy = AXActionEnumeratorSpy()
        tool = PerformAXActionTool(
            resolver: resolverSpy,
            interactor: interactorSpy,
            enumerator: enumeratorSpy,
            bridge: bridgeStub
        )
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "Target")
        enumeratorSpy.stubbedActions = [action]
        let params = makeParams(name: "perform_ax_action", args: [
            "title":  .string("Target"),
            "action": .string(action)
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(interactorSpy.lastAction, action,
                       "expected interactor to receive \(action)")
        XCTAssertNotEqual(result?.isError, true,
                          "\(action) should not be rejected by the whitelist")
    }

    // MARK: - Whitelist & allow_custom

    func test_execute_rejectsUnknownAction_whenAllowCustomIsFalse() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "OK")
        let params = makeParams(name: "perform_ax_action", args: [
            "title":  .string("OK"),
            "action": .string("AXNonsense")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("action_not_supported"),
                      "whitelist rejection should reuse the action_not_supported code; got: \(text)")
        XCTAssertEqual(interactorSpy.performCallCount, 0,
                       "no action dispatched when whitelist rejects")
        XCTAssertEqual(enumeratorSpy.callCount, 0,
                       "enumerator should not be queried when whitelist rejects early")
    }

    func test_execute_dispatchesUnknownAction_whenAllowCustomIsTrue() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "OK")
        enumeratorSpy.stubbedActions = ["AXShowAlternateUI"]
        let params = makeParams(name: "perform_ax_action", args: [
            "title":        .string("OK"),
            "action":       .string("AXShowAlternateUI"),
            "allow_custom": .bool(true)
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(interactorSpy.lastAction, "AXShowAlternateUI",
                       "allow_custom=true must let app-defined actions through")
        XCTAssertEqual(interactorSpy.performCallCount, 1)
    }

    func test_execute_rejectsCustomAction_whenAllowCustomTrueButElementDoesNotSupportIt() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "OK")
        enumeratorSpy.stubbedActions = ["AXPress"]  // does not include AXShowAlternateUI
        let params = makeParams(name: "perform_ax_action", args: [
            "title":        .string("OK"),
            "action":       .string("AXShowAlternateUI"),
            "allow_custom": .bool(true)
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true,
                       "allow_custom does not bypass the per-element supported check")
        XCTAssertEqual(interactorSpy.performCallCount, 0)
    }

    // MARK: - Input validation

    func test_execute_rejectsWhenNoLocatorProvided() async throws {
        let params = makeParams(name: "perform_ax_action", args: [
            "action": .string("AXPress")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.lowercased().contains("locator"),
                      "expected validation message about missing locator; got: \(text)")
        XCTAssertEqual(resolverSpy.callCount, 0)
        XCTAssertEqual(interactorSpy.performCallCount, 0)
    }

    func test_execute_returnsNotFound_whenResolverThrows() async throws {
        resolverSpy.stubbedError = AXNotFoundError(searchCriteria: "title=Missing")
        let params = makeParams(name: "perform_ax_action", args: [
            "title":  .string("Missing"),
            "action": .string("AXPress")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let text = extractText(from: result!) ?? ""
        XCTAssertTrue(text.contains("element_not_found"),
                      "expected element_not_found code; got: \(text)")
        XCTAssertEqual(interactorSpy.performCallCount, 0)
    }

    func test_execute_returnsResolutionError_whenResolverThrowsAXResolutionError() async throws {
        resolverSpy.stubbedError = AXResolutionError(
            detail: "search timeout", underlyingCode: -25204
        )
        let params = makeParams(name: "perform_ax_action", args: [
            "title":  .string("OK"),
            "action": .string("AXPress")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let inner = try result!.parseStructuredError()
        XCTAssertEqual(inner["code"] as? String, "ax_resolution_failed",
                       "expected resolution error code; got: \(inner)")
        XCTAssertEqual(interactorSpy.performCallCount, 0)
    }

    func test_execute_returnsActionError_whenInteractorThrows() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "Save")
        enumeratorSpy.stubbedActions = ["AXPress"]
        interactorSpy.simulatedError = AXActionError(
            code: .elementDisabled, action: "AXPress", detail: "disabled"
        )
        let params = makeParams(name: "perform_ax_action", args: [
            "title":  .string("Save"),
            "action": .string("AXPress")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let inner = try result!.parseStructuredError()
        XCTAssertEqual(inner["code"] as? String, "ax_element_disabled",
                       "expected disabled error code; got: \(inner)")
    }

    func test_execute_doesNotDispatch_whenEnumeratorThrows() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "OK")
        enumeratorSpy.stubbedError = AXResolutionError(
            detail: "AX bridge fault", underlyingCode: -25200
        )
        let params = makeParams(name: "perform_ax_action", args: [
            "title":  .string("OK"),
            "action": .string("AXPress")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        XCTAssertEqual(interactorSpy.performCallCount, 0,
                       "must not dispatch when supported-list lookup fails")
    }

    // MARK: - Application scope (mirrors click_element)

    func test_execute_appliesBundleIdScope_whenApplicationContainsDot() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "OK")
        enumeratorSpy.stubbedActions = ["AXPress"]
        let params = makeParams(name: "perform_ax_action", args: [
            "title":       .string("OK"),
            "application": .string("com.apple.TextEdit"),
            "action":      .string("AXPress")
        ])

        _ = try await tool.execute(params)

        guard case .bundleId(let bid)? = resolverSpy.lastScope else {
            return XCTFail("expected .bundleId scope; got \(String(describing: resolverSpy.lastScope))")
        }
        XCTAssertEqual(bid, "com.apple.TextEdit")
    }

    func test_execute_appliesNameScope_whenApplicationIsBareName() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "OK")
        enumeratorSpy.stubbedActions = ["AXPress"]
        let params = makeParams(name: "perform_ax_action", args: [
            "title":       .string("OK"),
            "application": .string("TextEdit"),
            "action":      .string("AXPress")
        ])

        _ = try await tool.execute(params)

        guard case .name(let n)? = resolverSpy.lastScope else {
            return XCTFail("expected .name scope; got \(String(describing: resolverSpy.lastScope))")
        }
        XCTAssertEqual(n, "TextEdit")
    }

    // MARK: - Locator dispatch precedence (mirrors click_element)

    func test_execute_dispatchesByIdentifier_whenIdentifierProvided() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXButton", title: "OK", identifier: "ax-ok-1"
        )
        enumeratorSpy.stubbedActions = ["AXPress"]
        let params = makeParams(name: "perform_ax_action", args: [
            "identifier": .string("ax-ok-1"),
            "title":      .string("OK"),
            "action":     .string("AXPress")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(resolverSpy.lastAttributeKind, .identifier)
        XCTAssertEqual(resolverSpy.lastAttributeValue, "ax-ok-1")
    }

    func test_execute_dispatchesByLabel_whenOnlyLabelProvided() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXCheckBox", label: "Spell")
        enumeratorSpy.stubbedActions = ["AXPress"]
        let params = makeParams(name: "perform_ax_action", args: [
            "label":  .string("Spell"),
            "action": .string("AXPress")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(resolverSpy.lastAttributeKind, .label)
        XCTAssertEqual(resolverSpy.lastAttributeValue, "Spell")
    }

    func test_execute_dispatchesByDescription_whenOnlyDescriptionProvided() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXButton", description: "Close window"
        )
        enumeratorSpy.stubbedActions = ["AXPress"]
        let params = makeParams(name: "perform_ax_action", args: [
            "description": .string("Close window"),
            "action":      .string("AXPress")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(resolverSpy.lastAttributeKind, .description)
        XCTAssertEqual(resolverSpy.lastAttributeValue, "Close window")
    }

    func test_execute_dispatchesByRole_whenOnlyRoleProvided() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton")
        enumeratorSpy.stubbedActions = ["AXPress"]
        let params = makeParams(name: "perform_ax_action", args: [
            "role":   .string("AXButton"),
            "action": .string("AXPress")
        ])

        _ = try await tool.execute(params)

        XCTAssertEqual(resolverSpy.lastAttributeKind, .role)
        XCTAssertEqual(resolverSpy.lastAttributeValue, "AXButton")
    }

    // MARK: - Post-validation mismatches (AND-filter across attributes)

    func test_execute_postValidatesRoleMismatch() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXStaticText", title: "OK", identifier: "ax-ok-1"
        )
        let params = makeParams(name: "perform_ax_action", args: [
            "identifier": .string("ax-ok-1"),
            "role":       .string("AXButton"),
            "action":     .string("AXPress")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        XCTAssertEqual(interactorSpy.performCallCount, 0)
    }

    func test_execute_postValidatesTitleMismatch() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXButton", title: "Wrong", identifier: "ax-ok-1"
        )
        let params = makeParams(name: "perform_ax_action", args: [
            "identifier": .string("ax-ok-1"),
            "title":      .string("OK"),
            "action":     .string("AXPress")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        XCTAssertEqual(interactorSpy.performCallCount, 0)
    }

    func test_execute_postValidatesLabelMismatch() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXButton", identifier: "ax-ok-1", label: "Actual"
        )
        let params = makeParams(name: "perform_ax_action", args: [
            "identifier": .string("ax-ok-1"),
            "label":      .string("Wrong"),
            "action":     .string("AXPress")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        XCTAssertEqual(interactorSpy.performCallCount, 0)
    }

    func test_execute_postValidatesDescriptionMismatch() async throws {
        resolverSpy.stubbedResult = .mockReference(
            role: "AXButton", identifier: "ax-ok-1", description: "Actual"
        )
        let params = makeParams(name: "perform_ax_action", args: [
            "identifier":  .string("ax-ok-1"),
            "description": .string("Wrong"),
            "action":      .string("AXPress")
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        XCTAssertEqual(interactorSpy.performCallCount, 0)
    }

    // MARK: - Discovery error path

    func test_execute_discovery_returnsResolutionError_whenEnumeratorThrowsAXResolutionError() async throws {
        resolverSpy.stubbedResult = .mockReference(role: "AXButton", title: "OK")
        enumeratorSpy.stubbedError = AXResolutionError(
            detail: "AX bridge fault", underlyingCode: -25200
        )
        let params = makeParams(name: "perform_ax_action", args: [
            "title": .string("OK")
            // no action → discovery path
        ])

        let result = try await tool.execute(params)

        XCTAssertEqual(result?.isError, true)
        let inner = try result!.parseStructuredError()
        XCTAssertEqual(inner["code"] as? String, "ax_resolution_failed",
                       "discovery's AXResolutionError must surface; got: \(inner)")
    }
}
