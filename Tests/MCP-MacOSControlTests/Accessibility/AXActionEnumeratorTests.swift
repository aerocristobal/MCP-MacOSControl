// STORY-003 — AX Action Performer Tool
// COMPONENT: AXActionEnumerator

import XCTest
import ApplicationServices
@testable import MacOSControlLib

final class AXActionEnumeratorTests: XCTestCase {

    var bridge: MockAXApplicationBridge!
    var enumerator: AXActionEnumerator!

    override func setUp() {
        super.setUp()
        bridge = MockAXApplicationBridge(elements: [])
        enumerator = AXActionEnumerator(bridge: bridge)
    }

    func test_actionNames_returnsActionsFromBridge() throws {
        bridge = MockAXApplicationBridge(elements: [
            MockAXUIElement(role: "AXButton", title: "OK", pid: 1,
                            supportedActions: ["AXPress", "AXConfirm"])
        ])
        enumerator = AXActionEnumerator(bridge: bridge)
        guard let ref = try bridge.windows(forPID: 1).first else {
            return XCTFail("setup failed: no element")
        }

        let actions = try enumerator.actionNames(for: ref)

        XCTAssertEqual(actions, ["AXPress", "AXConfirm"])
    }

    func test_actionNames_returnsEmptyArray_forElementWithNoActions() throws {
        bridge = MockAXApplicationBridge(elements: [
            MockAXUIElement(role: "AXStaticText", title: "Version", pid: 1,
                            supportedActions: [])
        ])
        enumerator = AXActionEnumerator(bridge: bridge)
        guard let ref = try bridge.windows(forPID: 1).first else {
            return XCTFail("setup failed: no element")
        }

        let actions = try enumerator.actionNames(for: ref)

        XCTAssertTrue(actions.isEmpty)
    }

    func test_actionNames_throwsWhenAXAPIReturnsError() {
        bridge = MockAXApplicationBridge(
            elements: [MockAXUIElement(role: "AXButton", title: "OK", pid: 1)],
            simulatedAXError: nil
        )
        let ref = AXElementReference.mockReference(role: "AXButton", title: "OK")
        bridge.simulatedAXError = .cannotComplete
        enumerator = AXActionEnumerator(bridge: bridge)

        XCTAssertThrowsError(try enumerator.actionNames(for: ref)) { error in
            XCTAssertTrue(error is AXResolutionError,
                          "expected AXResolutionError; got \(type(of: error))")
        }
    }

    func test_actionNames_passesElementReferenceThroughToBridge() throws {
        bridge = MockAXApplicationBridge(elements: [
            MockAXUIElement(role: "AXButton", title: "OK", pid: 1,
                            supportedActions: ["AXPress"])
        ])
        enumerator = AXActionEnumerator(bridge: bridge)
        guard let ref = try bridge.windows(forPID: 1).first else {
            return XCTFail("setup failed: no element")
        }

        _ = try enumerator.actionNames(for: ref)

        XCTAssertEqual(bridge.copyActionNamesCallCount, 1)
        XCTAssertEqual(bridge.lastCopyActionNamesElement?.title, "OK")
    }
}
