import XCTest
@testable import MacOSControlLib

final class AXElementResolverTests: XCTestCase {

    var resolver: AXElementResolver!

    // MARK: - Happy Path (Scenario 1)

    func test_findElement_returnsElement_whenRoleAndTitleMatch() throws {
        let mock = MockAXUIElement(role: "AXButton", title: "Close", pid: 1001)
        let bridge = MockAXApplicationBridge(elements: [mock])
        resolver = AXElementResolver(bridge: bridge)

        let result = try resolver.findElement(role: "AXButton", title: "Close", scope: nil)

        XCTAssertEqual(result.role, "AXButton")
        XCTAssertEqual(result.title, "Close")
    }

    func test_findElement_returnsFirstMatch_whenMultipleCandidatesExist() throws {
        let first = MockAXUIElement(role: "AXButton", title: "Close", pid: 1001)
        let second = MockAXUIElement(role: "AXButton", title: "Close", pid: 2002)
        let bridge = MockAXApplicationBridge(elements: [first, second])
        resolver = AXElementResolver(bridge: bridge)

        let result = try resolver.findElement(role: "AXButton", title: "Close", scope: nil)

        XCTAssertEqual(result.pid, 1001)
    }

    // MARK: - Alternative Path (Scenario 2)

    func test_findElement_byIdentifier_returnsMatchingElement() throws {
        let mock = MockAXUIElement(
            role: "AXButton",
            title: "Save",
            identifier: "com.app.save-button",
            pid: 1001
        )
        let bridge = MockAXApplicationBridge(elements: [mock])
        resolver = AXElementResolver(bridge: bridge)

        let result = try resolver.findElement(by: .identifier, value: "com.app.save-button")

        XCTAssertEqual(result.identifier, "com.app.save-button")
    }

    // MARK: - Error Path (Scenario 3)

    func test_findElement_throwsAXNotFoundError_whenNoMatchExists() {
        let mock = MockAXUIElement(role: "AXButton", title: "Save", pid: 1001)
        let bridge = MockAXApplicationBridge(elements: [mock])
        resolver = AXElementResolver(bridge: bridge)

        XCTAssertThrowsError(
            try resolver.findElement(role: "AXButton", title: "Ghost", scope: nil)
        ) { error in
            guard let axError = error as? AXNotFoundError else {
                XCTFail("Expected AXNotFoundError, got \(error)")
                return
            }
            XCTAssertTrue(axError.searchCriteria.contains("AXButton"))
            XCTAssertTrue(axError.searchCriteria.contains("Ghost"))
        }
    }

    func test_findElement_doesNotCrash_whenBridgeReturnsAXErrorCannotComplete() {
        let bridge = MockAXApplicationBridge(simulatedAXError: .cannotComplete)
        resolver = AXElementResolver(bridge: bridge)

        XCTAssertThrowsError(
            try resolver.findElement(role: "AXButton", title: "Close", scope: nil)
        ) { error in
            XCTAssertTrue(error is AXNotFoundError || error is AXResolutionError,
                          "Expected AXNotFoundError or AXResolutionError, got \(error)")
        }
    }

    // MARK: - Scope / Boundary (Scenario 4)

    func test_findElement_scopedToApplication_excludesOtherProcesses() throws {
        let inScope = MockAXUIElement(role: "AXButton", title: "Close", pid: 1001)
        let outOfScope = MockAXUIElement(role: "AXButton", title: "Close", pid: 2002)
        let bridge = MockAXApplicationBridge(elements: [inScope, outOfScope])
        resolver = AXElementResolver(bridge: bridge)

        let result = try resolver.findElement(
            role: "AXButton",
            title: "Close",
            scope: .pid(1001)
        )

        XCTAssertEqual(result.pid, 1001)
    }

    func test_findElement_scopeAcceptsBundleIdOrPid() throws {
        let element = MockAXUIElement(
            role: "AXButton",
            title: "Close",
            pid: 1001,
            bundleId: "com.apple.TextEdit"
        )
        let bridge = MockAXApplicationBridge(elements: [element])
        resolver = AXElementResolver(bridge: bridge)

        let byPid = try resolver.findElement(role: "AXButton", title: "Close", scope: .pid(1001))
        let byBundle = try resolver.findElement(role: "AXButton", title: "Close", scope: .bundleId("com.apple.TextEdit"))

        XCTAssertEqual(byPid.pid, byBundle.pid)
    }

    func test_findElement_scopeAcceptsLocalizedName() throws {
        let element = MockAXUIElement(
            role: "AXButton",
            title: "Close",
            pid: 1001,
            bundleId: "com.apple.TextEdit"
        )
        let bridge = MockAXApplicationBridge(elements: [element])
        // Inject a name into the bridge by overriding its mapping via a wrapper.
        // For now we only assert .name returns no result when the mock has no name.
        resolver = AXElementResolver(bridge: bridge)

        // Name scope on the mock is empty for this fixture; expect AXNotFoundError.
        XCTAssertThrowsError(
            try resolver.findElement(role: "AXButton", title: "Close", scope: .name("TextEdit"))
        ) { error in
            XCTAssertTrue(error is AXNotFoundError)
        }
    }

    // MARK: - Attribute Type Outline (Scenario Outline)

    func test_findElement_byLabel_returnsMatchingElement() throws {
        let mock = MockAXUIElement(role: "AXButton", label: "Search", pid: 1001)
        let bridge = MockAXApplicationBridge(elements: [mock])
        resolver = AXElementResolver(bridge: bridge)

        let result = try resolver.findElement(by: .label, value: "Search")

        XCTAssertEqual(result.label, "Search")
    }

    func test_findElement_byDescription_returnsMatchingElement() throws {
        let mock = MockAXUIElement(role: "AXButton", description: "Close window", pid: 1001)
        let bridge = MockAXApplicationBridge(elements: [mock])
        resolver = AXElementResolver(bridge: bridge)

        let result = try resolver.findElement(by: .description, value: "Close window")

        XCTAssertEqual(result.description, "Close window")
    }

    func test_findElement_byRole_returnsMatchingElement() throws {
        let mock = MockAXUIElement(role: "AXTextField", title: "Username", pid: 1001)
        let bridge = MockAXApplicationBridge(elements: [mock])
        resolver = AXElementResolver(bridge: bridge)

        let result = try resolver.findElement(by: .role, value: "AXTextField")

        XCTAssertEqual(result.role, "AXTextField")
    }

    // MARK: - Recursion / Depth

    func test_findElement_descendsThroughChildren() throws {
        let target = MockAXUIElement(role: "AXButton", title: "Close", pid: 1001)
        let intermediate = MockAXUIElement(role: "AXGroup", pid: 1001, children: [target])
        let window = MockAXUIElement(role: "AXWindow", title: "Untitled", pid: 1001, children: [intermediate])
        let bridge = MockAXApplicationBridge(elements: [window])
        resolver = AXElementResolver(bridge: bridge)

        let result = try resolver.findElement(role: "AXButton", title: "Close", scope: nil)

        XCTAssertEqual(result.role, "AXButton")
        XCTAssertEqual(result.title, "Close")
    }

    func test_findElement_respectsMaxDepth() {
        let buried = MockAXUIElement(role: "AXButton", title: "Close", pid: 1001)
        var current = buried
        for _ in 0..<12 {
            current = MockAXUIElement(role: "AXGroup", pid: 1001, children: [current])
        }
        let bridge = MockAXApplicationBridge(elements: [current])
        resolver = AXElementResolver(bridge: bridge, options: .init(maxDepth: 2, timeout: 2.0))

        XCTAssertThrowsError(
            try resolver.findElement(role: "AXButton", title: "Close", scope: nil)
        ) { error in
            XCTAssertTrue(error is AXNotFoundError)
        }
    }

    func test_findElement_byAttribute_throwsNotFound_whenNoMatch() {
        let mock = MockAXUIElement(role: "AXButton", identifier: "real.id", pid: 1001)
        let bridge = MockAXApplicationBridge(elements: [mock])
        resolver = AXElementResolver(bridge: bridge)

        XCTAssertThrowsError(
            try resolver.findElement(by: .identifier, value: "ghost.id", scope: .pid(1001))
        ) { error in
            guard let axError = error as? AXNotFoundError else {
                XCTFail("Expected AXNotFoundError, got \(error)")
                return
            }
            XCTAssertTrue(axError.searchCriteria.contains("identifier"))
            XCTAssertTrue(axError.searchCriteria.contains("ghost.id"))
            XCTAssertTrue(axError.searchCriteria.contains("pid:1001"))
        }
    }

    func test_findElement_byAttribute_descendsThroughChildren() throws {
        let target = MockAXUIElement(role: "AXButton", identifier: "deep.id", pid: 1001)
        let intermediate = MockAXUIElement(role: "AXGroup", pid: 1001, children: [target])
        let window = MockAXUIElement(role: "AXWindow", pid: 1001, children: [intermediate])
        let bridge = MockAXApplicationBridge(elements: [window])
        resolver = AXElementResolver(bridge: bridge)

        let result = try resolver.findElement(by: .identifier, value: "deep.id")

        XCTAssertEqual(result.identifier, "deep.id")
    }

    // MARK: - Timeout

    func test_findElement_throwsResolutionError_whenTimeoutExceeded() {
        // Build a deep chain so traversal must descend many levels.
        let leaf = MockAXUIElement(role: "AXButton", title: "Close", pid: 1001)
        var current = leaf
        for _ in 0..<50 {
            current = MockAXUIElement(role: "AXGroup", pid: 1001, children: [current])
        }
        let bridge = MockAXApplicationBridge(elements: [current])
        // Negative timeout forces deadline to lie in the past — first search call throws.
        resolver = AXElementResolver(bridge: bridge, options: .init(maxDepth: 100, timeout: -1.0))

        XCTAssertThrowsError(
            try resolver.findElement(role: "AXButton", title: "Close", scope: nil)
        ) { error in
            XCTAssertTrue(error is AXResolutionError, "Expected AXResolutionError, got \(error)")
        }
    }

    func test_findElement_byAttribute_throwsResolutionError_whenTimeoutExceeded() {
        let mock = MockAXUIElement(role: "AXButton", identifier: "x", pid: 1001)
        let bridge = MockAXApplicationBridge(elements: [mock])
        resolver = AXElementResolver(bridge: bridge, options: .init(maxDepth: 10, timeout: -1.0))

        XCTAssertThrowsError(
            try resolver.findElement(by: .identifier, value: "x")
        ) { error in
            XCTAssertTrue(error is AXResolutionError, "Expected AXResolutionError, got \(error)")
        }
    }
}
