// STORY: STORY-013 — MCP Resources for Ambient Context
// COMPONENT: CompositeEventLifecycle

import XCTest
@testable import MacOSControlLib

final class CompositeEventLifecycleTests: XCTestCase {

    func test_addObserver_installsObserverOnEachUnderlyingSource() {
        let a = MockWorkspaceObserverLifecycle()
        let b = MockWorkspaceObserverLifecycle()
        let composite = CompositeEventLifecycle([a, b])

        _ = composite.addAppActivationObserver { }

        XCTAssertEqual(a.activeObserverCount, 1)
        XCTAssertEqual(b.activeObserverCount, 1)
    }

    func test_handlerFires_whenAnyUnderlyingSourceFires() {
        let a = MockWorkspaceObserverLifecycle()
        let b = MockWorkspaceObserverLifecycle()
        let composite = CompositeEventLifecycle([a, b])

        var fireCount = 0
        _ = composite.addAppActivationObserver { fireCount += 1 }

        a.fireActivation()
        XCTAssertEqual(fireCount, 1)
        b.fireActivation()
        XCTAssertEqual(fireCount, 2)
    }

    func test_remove_dropsObserverFromEachUnderlyingSource() {
        let a = MockWorkspaceObserverLifecycle()
        let b = MockWorkspaceObserverLifecycle()
        let composite = CompositeEventLifecycle([a, b])
        let token = composite.addAppActivationObserver { }

        composite.remove(token)

        XCTAssertEqual(a.activeObserverCount, 0)
        XCTAssertEqual(b.activeObserverCount, 0)
        XCTAssertEqual(composite.activeObserverCount, 0)
    }

    func test_remove_isIdempotent() {
        let a = MockWorkspaceObserverLifecycle()
        let composite = CompositeEventLifecycle([a])
        let token = composite.addAppActivationObserver { }

        composite.remove(token)
        composite.remove(token)

        XCTAssertEqual(a.activeObserverCount, 0)
    }
}
