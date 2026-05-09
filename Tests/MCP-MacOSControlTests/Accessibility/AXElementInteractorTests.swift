// STORY-002 — Semantic Element Click Tool
// COMPONENT: AXElementInteractor (press-only path)

import XCTest
import ApplicationServices
@testable import MacOSControlLib

final class AXElementInteractorTests: XCTestCase {

    var bridge: MockAXApplicationBridge!
    var interactor: AXElementInteractor!

    override func setUp() {
        super.setUp()
        bridge = MockAXApplicationBridge(elements: [
            MockAXUIElement(role: "AXButton", title: "OK", pid: 1)
        ])
        interactor = AXElementInteractor(bridge: bridge)
    }

    private func reference(forTitle title: String, pid: pid_t = 1) throws -> AXElementReference {
        let windows = try bridge.windows(forPID: pid)
        guard let match = windows.first(where: { $0.title == title }) else {
            throw NSError(domain: "test", code: 1)
        }
        return match
    }

    // MARK: - Happy path

    func test_performPress_invokesAXPerformAction_withKAXPressAction() throws {
        let element = try reference(forTitle: "OK")

        try interactor.performPress(element)

        XCTAssertEqual(bridge.lastPerformedAction, kAXPressAction as String)
        XCTAssertEqual(bridge.lastTargetElement?.title, "OK")
    }

    func test_performPress_doesNotMutateElement() throws {
        let element = try reference(forTitle: "OK")
        let originalTitle = element.title

        try interactor.performPress(element)

        XCTAssertEqual(element.title, originalTitle)
    }

    // MARK: - Error paths

    func test_performPress_throwsActionFailed_whenBridgeReturnsError() throws {
        let element = try reference(forTitle: "OK")
        bridge.simulatedAXError = .actionUnsupported

        XCTAssertThrowsError(try interactor.performPress(element)) { error in
            XCTAssertTrue(error is AXActionError, "expected AXActionError, got \(type(of: error))")
            if let actionError = error as? AXActionError {
                XCTAssertEqual(actionError.code, .actionFailed)
                XCTAssertEqual(actionError.action, kAXPressAction as String)
            }
        }
    }

    func test_performPress_throwsElementDisabled_whenAXEnabledIsFalse() {
        let disabledBridge = MockAXApplicationBridge(elements: [
            MockAXUIElement(role: "AXButton", title: "Save", pid: 1, enabled: false)
        ])
        let interactor = AXElementInteractor(bridge: disabledBridge)
        let windows = try? disabledBridge.windows(forPID: 1)
        guard let element = windows?.first else { return XCTFail("setup failed") }

        XCTAssertThrowsError(try interactor.performPress(element)) { error in
            guard let actionError = error as? AXActionError else {
                return XCTFail("expected AXActionError, got \(type(of: error))")
            }
            XCTAssertEqual(actionError.code, .elementDisabled)
        }
        XCTAssertEqual(disabledBridge.performActionCallCount, 0,
                       "must not dispatch AXPress on disabled element")
    }
}
