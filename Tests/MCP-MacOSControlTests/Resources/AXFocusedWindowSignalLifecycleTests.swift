// STORY: STORY-013 — MCP Resources for Ambient Context
// COMPONENT: AXFocusedWindowSignalLifecycle

import XCTest
@testable import MacOSControlLib

final class AXFocusedWindowSignalLifecycleTests: XCTestCase {

    var workspaceLifecycle: MockWorkspaceObserverLifecycle!
    var workspaceProvider: MockWorkspaceProvider!
    var sourceFactory: MockAXFocusedWindowSourceFactory!
    var lifecycle: AXFocusedWindowSignalLifecycle!

    override func setUp() {
        super.setUp()
        workspaceLifecycle = MockWorkspaceObserverLifecycle()
        workspaceProvider = MockWorkspaceProvider()
        sourceFactory = MockAXFocusedWindowSourceFactory()
        workspaceProvider.frontmostApplication = FrontmostApplicationInfo(
            localizedName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 12345
        )
        lifecycle = AXFocusedWindowSignalLifecycle(
            workspaceLifecycle: workspaceLifecycle,
            workspaceProvider: workspaceProvider,
            sourceFactory: sourceFactory
        )
    }

    // MARK: - Scenario 4 — within-app window switch fires the handler

    func test_focusedWindowChange_firesHandler() {
        var fireCount = 0
        _ = lifecycle.addAppActivationObserver { fireCount += 1 }

        sourceFactory.latest?.fireFocusedWindowChange()

        XCTAssertEqual(fireCount, 1,
                       "AX focused-window change must propagate to the registered handler")
    }

    func test_subscribe_installsAXSourceForCurrentFrontmostApp() {
        _ = lifecycle.addAppActivationObserver { }

        XCTAssertEqual(sourceFactory.requestedPIDs, [12345])
        XCTAssertEqual(sourceFactory.latest?.isStarted, true)
        XCTAssertTrue(lifecycle.hasActiveAXSource)
    }

    // MARK: - Re-targeting when frontmost app changes

    func test_workspaceActivation_reTargetsAXSourceToNewPID() {
        _ = lifecycle.addAppActivationObserver { }
        let originalSource = sourceFactory.latest
        XCTAssertEqual(originalSource?.pid, 12345)

        workspaceProvider.frontmostApplication = FrontmostApplicationInfo(
            localizedName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            processIdentifier: 67890
        )
        workspaceLifecycle.fireActivation()

        XCTAssertEqual(originalSource?.isStarted, false,
                       "Previous AX source must be stopped before re-targeting")
        XCTAssertEqual(sourceFactory.requestedPIDs, [12345, 67890])
        XCTAssertEqual(sourceFactory.latest?.pid, 67890)
        XCTAssertEqual(sourceFactory.latest?.isStarted, true)
    }

    func test_workspaceActivation_doesNotReTarget_whenPIDUnchanged() {
        _ = lifecycle.addAppActivationObserver { }
        workspaceLifecycle.fireActivation()

        XCTAssertEqual(sourceFactory.requestedPIDs, [12345],
                       "Activation without a real PID change must not allocate a fresh AX source")
    }

    func test_workspaceActivation_alsoFiresHandler() {
        var fireCount = 0
        _ = lifecycle.addAppActivationObserver { fireCount += 1 }

        workspaceProvider.frontmostApplication = FrontmostApplicationInfo(
            localizedName: "Safari", bundleIdentifier: nil, processIdentifier: 67890
        )
        workspaceLifecycle.fireActivation()

        XCTAssertEqual(fireCount, 1,
                       "App-switch is itself a focused-window-change from the subscriber's POV")
    }

    // MARK: - Observer cleanup — leak guard

    func test_remove_stopsAXSource_andDropsWorkspaceObserver() {
        let token = lifecycle.addAppActivationObserver { }
        XCTAssertTrue(lifecycle.hasActiveAXSource)
        XCTAssertEqual(workspaceLifecycle.activeObserverCount, 1)

        lifecycle.remove(token)

        XCTAssertFalse(lifecycle.hasActiveAXSource,
                       "AX source must be stopped when the last subscriber leaves")
        XCTAssertEqual(workspaceLifecycle.activeObserverCount, 0,
                       "Inner workspace observer must be removed alongside the AX source")
        XCTAssertEqual(sourceFactory.latest?.stopCount, 1)
    }

    func test_remove_keepsAXSource_whileOtherSubscribersRemain() {
        let tokenA = lifecycle.addAppActivationObserver { }
        _ = lifecycle.addAppActivationObserver { }

        lifecycle.remove(tokenA)

        XCTAssertTrue(lifecycle.hasActiveAXSource,
                      "AX source must remain while other subscribers are still attached")
    }
}
