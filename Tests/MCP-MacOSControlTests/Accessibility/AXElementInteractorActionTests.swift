// STORY-003 — AX Action Performer Tool
// COMPONENT: AXElementInteractor (general perform path + STORY-002 regression)

import XCTest
import ApplicationServices
@testable import MacOSControlLib

final class AXElementInteractorActionTests: XCTestCase {

    var bridge: MockAXApplicationBridge!
    var interactor: AXElementInteractor!

    override func setUp() {
        super.setUp()
        bridge = MockAXApplicationBridge(elements: [])
        interactor = AXElementInteractor(bridge: bridge)
    }

    // MARK: - Generic perform(_:on:)

    func test_perform_dispatchesCorrectActionConstant() throws {
        bridge = MockAXApplicationBridge(elements: [
            MockAXUIElement(role: "AXSlider", title: "Volume", pid: 1)
        ])
        interactor = AXElementInteractor(bridge: bridge)
        guard let ref = try bridge.windows(forPID: 1).first else {
            return XCTFail("setup failed")
        }

        try interactor.perform("AXIncrement", on: ref)

        XCTAssertEqual(bridge.lastPerformedAction, "AXIncrement")
        XCTAssertEqual(bridge.lastTargetElement?.title, "Volume")
        XCTAssertEqual(bridge.performActionCallCount, 1)
    }

    func test_perform_dispatchesEachStandardActionUnchanged() throws {
        let standardActions = ["AXPress", "AXIncrement", "AXDecrement",
                               "AXConfirm", "AXCancel", "AXShowMenu",
                               "AXRaise", "AXPick"]

        for action in standardActions {
            bridge = MockAXApplicationBridge(elements: [
                MockAXUIElement(role: "AXButton", title: "Target", pid: 1)
            ])
            interactor = AXElementInteractor(bridge: bridge)
            guard let ref = try bridge.windows(forPID: 1).first else {
                return XCTFail("setup failed for \(action)")
            }

            try interactor.perform(action, on: ref)

            XCTAssertEqual(bridge.lastPerformedAction, action,
                           "expected bridge to receive \(action) verbatim")
        }
    }

    func test_perform_throwsElementDisabledError_whenElementNotEnabled() throws {
        bridge = MockAXApplicationBridge(elements: [
            MockAXUIElement(role: "AXButton", title: "Save", pid: 1, enabled: false)
        ])
        interactor = AXElementInteractor(bridge: bridge)
        guard let ref = try bridge.windows(forPID: 1).first else {
            return XCTFail("setup failed")
        }

        XCTAssertThrowsError(try interactor.perform("AXIncrement", on: ref)) { error in
            guard let actionError = error as? AXActionError else {
                return XCTFail("expected AXActionError; got \(type(of: error))")
            }
            XCTAssertEqual(actionError.code, .elementDisabled)
            XCTAssertEqual(actionError.action, "AXIncrement",
                           "must report the dynamic action name, not 'AXPress'")
        }
        XCTAssertEqual(bridge.performActionCallCount, 0,
                       "no action must reach the bridge when element is disabled")
    }

    func test_perform_wrapsBridgeFailureAsActionFailedError() throws {
        bridge = MockAXApplicationBridge(
            elements: [MockAXUIElement(role: "AXButton", title: "OK", pid: 1)],
            simulatedAXError: .cannotComplete
        )
        interactor = AXElementInteractor(bridge: bridge)
        let ref = AXElementReference.mockReference(role: "AXButton", title: "OK")

        XCTAssertThrowsError(try interactor.perform("AXShowMenu", on: ref)) { error in
            guard let actionError = error as? AXActionError else {
                return XCTFail("expected AXActionError; got \(type(of: error))")
            }
            XCTAssertEqual(actionError.code, .actionFailed)
            XCTAssertEqual(actionError.action, "AXShowMenu")
        }
    }

    // MARK: - STORY-002 regression: performPress must still work

    func test_performPress_stillFunctional_afterStory003Refactor() throws {
        bridge = MockAXApplicationBridge(elements: [
            MockAXUIElement(role: "AXButton", title: "OK", pid: 1)
        ])
        interactor = AXElementInteractor(bridge: bridge)
        guard let ref = try bridge.windows(forPID: 1).first else {
            return XCTFail("setup failed")
        }

        try interactor.performPress(ref)

        XCTAssertEqual(bridge.lastPerformedAction, "AXPress",
                       "performPress must still dispatch AXPress after refactor")
        XCTAssertEqual(bridge.performActionCallCount, 1)
    }
}
