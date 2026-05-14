// STORY: STORY-013 — MCP Resources for Ambient Context
// COMPONENT: ActiveWindowTreeResource

import XCTest
@testable import MacOSControlLib

final class ActiveWindowTreeResourceTests: XCTestCase {

    var workspace: MockWorkspaceProvider!
    var bridge: MockAXApplicationBridge!
    var permission: MockAccessibilityPermissionChecker!
    var dateProvider: MockDateProvider!
    var resource: ActiveWindowTreeResource!

    override func setUp() {
        super.setUp()
        workspace = MockWorkspaceProvider()
        bridge = MockAXApplicationBridge(elements: [])
        permission = MockAccessibilityPermissionChecker()
        dateProvider = MockDateProvider()
        resource = ActiveWindowTreeResource(
            workspace: workspace,
            permission: permission,
            builder: AccessibilityTreeBuilder(bridge: bridge),
            serializer: AXNodeSerializer(),
            dateProvider: dateProvider
        )
    }

    private func installApplicationRoot(pid: pid_t, role: String, title: String? = nil,
                                        children: [MockAXUIElement] = []) {
        let root = MockAXUIElement(role: role, title: title, pid: pid, children: children)
        bridge.applicationRoots[pid] = root
    }

    // MARK: - Scenario 2 — happy path

    func test_read_returnsTreeForFrontmostApp_withSerializerSchema() throws {
        workspace.frontmostApplication = FrontmostApplicationInfo(
            localizedName: "TextEdit", bundleIdentifier: "com.apple.TextEdit", processIdentifier: 12345
        )
        installApplicationRoot(
            pid: 12345,
            role: "AXApplication",
            children: [
                MockAXUIElement(role: "AXWindow", title: "Document", pid: 12345, children: [
                    MockAXUIElement(role: "AXButton", title: "Save", pid: 12345, supportedActions: ["AXPress"])
                ])
            ]
        )

        let content = try resource.read()

        XCTAssertEqual(content["role"] as? String, "AXApplication")
        XCTAssertEqual(content["schema_version"] as? Int, AXNodeSerializer.schemaVersion,
                       "Resource must inherit current serializer schema_version")
    }

    func test_read_passesMaxDepthToBuilder() throws {
        workspace.frontmostApplication = FrontmostApplicationInfo(
            localizedName: "TextEdit", bundleIdentifier: nil, processIdentifier: 12345
        )
        installApplicationRoot(
            pid: 12345,
            role: "AXApplication",
            children: [
                MockAXUIElement(role: "AXWindow", title: "Doc", pid: 12345, children: [
                    MockAXUIElement(role: "AXGroup", pid: 12345, children: [
                        MockAXUIElement(role: "AXButton", title: "Deep", pid: 12345)
                    ])
                ])
            ]
        )

        let shallow = try resource.read(maxDepth: 1)
        let children = shallow["children"] as? [[String: Any]]
        XCTAssertEqual(children?.count, 1)
        // With max_depth=1, the AXWindow level is included but its grandchild AXButton is pruned.
        let window = children?.first
        XCTAssertEqual(window?["role"] as? String, "AXWindow")
        XCTAssertEqual(window?["truncated"] as? Bool, true,
                       "AXWindow children should be pruned at max_depth=1 — but bumping cache keying ensures the deeper read is treated as a different cache entry")
    }

    // MARK: - Scenario 6 — accessibility permission error

    func test_read_returnsAccessibilityPermissionRequiredError_whenAXNotTrusted() {
        permission.trusted = false
        workspace.frontmostApplication = FrontmostApplicationInfo(
            localizedName: "TextEdit", bundleIdentifier: nil, processIdentifier: 12345
        )

        XCTAssertThrowsError(try resource.read()) { error in
            guard case MCPError.accessibilityPermissionRequired = error else {
                return XCTFail("Expected .accessibilityPermissionRequired, got \(error)")
            }
        }
    }

    // MARK: - no_frontmost_application reuse for the tree resource

    func test_read_returnsNoFrontmostApplicationError_whenWorkspaceReturnsNil() {
        workspace.frontmostApplication = nil

        XCTAssertThrowsError(try resource.read()) { error in
            guard case MCPError.noFrontmostApplication = error else {
                return XCTFail("Expected .noFrontmostApplication, got \(error)")
            }
        }
    }

    // MARK: - 100ms read cache

    func test_read_returnsCachedTree_whenCalledWithin100ms() throws {
        workspace.frontmostApplication = FrontmostApplicationInfo(
            localizedName: "TextEdit", bundleIdentifier: nil, processIdentifier: 12345
        )
        installApplicationRoot(pid: 12345, role: "AXApplication")
        bridge.applicationRoots[12345] = MockAXUIElement(role: "AXApplication", pid: 12345, children: [
            MockAXUIElement(role: "AXButton", title: "Cached", pid: 12345, supportedActions: ["AXPress"])
        ])

        _ = try resource.read()
        let actionsCountAfterFirstRead = bridge.copyActionNamesCallCount

        // Advance less than the 100ms TTL.
        dateProvider.advance(by: 0.05)
        _ = try resource.read()

        XCTAssertEqual(bridge.copyActionNamesCallCount, actionsCountAfterFirstRead,
                       "Second read within 100ms cache window must not re-walk the AX tree")
    }

    func test_read_rebuildsTree_afterCacheExpires() throws {
        workspace.frontmostApplication = FrontmostApplicationInfo(
            localizedName: "TextEdit", bundleIdentifier: nil, processIdentifier: 12345
        )
        bridge.applicationRoots[12345] = MockAXUIElement(role: "AXApplication", pid: 12345, children: [
            MockAXUIElement(role: "AXButton", title: "Fresh", pid: 12345, supportedActions: ["AXPress"])
        ])

        _ = try resource.read()
        let actionsCountAfterFirstRead = bridge.copyActionNamesCallCount

        dateProvider.advance(by: 0.2)
        _ = try resource.read()

        XCTAssertEqual(bridge.copyActionNamesCallCount, actionsCountAfterFirstRead * 2,
                       "Read after cache TTL expires must rebuild the tree")
    }

    func test_invalidateCache_forcesRebuildOnNextRead() throws {
        workspace.frontmostApplication = FrontmostApplicationInfo(
            localizedName: "TextEdit", bundleIdentifier: nil, processIdentifier: 12345
        )
        bridge.applicationRoots[12345] = MockAXUIElement(role: "AXApplication", pid: 12345, children: [
            MockAXUIElement(role: "AXButton", title: "X", pid: 12345, supportedActions: ["AXPress"])
        ])

        _ = try resource.read()
        let before = bridge.copyActionNamesCallCount
        resource.invalidateCache()
        _ = try resource.read()

        XCTAssertEqual(bridge.copyActionNamesCallCount, before * 2,
                       "invalidateCache must force a fresh AX walk on the next read")
    }
}
