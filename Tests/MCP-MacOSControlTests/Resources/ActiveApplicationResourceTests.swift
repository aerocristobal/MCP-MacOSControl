// STORY: STORY-013 — MCP Resources for Ambient Context
// COMPONENT: ActiveApplicationResource

import XCTest
@testable import MacOSControlLib

final class ActiveApplicationResourceTests: XCTestCase {

    var workspace: MockWorkspaceProvider!
    var resource: ActiveApplicationResource!

    override func setUp() {
        super.setUp()
        workspace = MockWorkspaceProvider()
        resource = ActiveApplicationResource(workspace: workspace)
    }

    // MARK: - Scenario 1 — happy path

    func test_read_returnsLocalizedName_bundleId_andPID() throws {
        workspace.frontmostApplication = FrontmostApplicationInfo(
            localizedName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            processIdentifier: 12345
        )

        let content = try resource.read()

        XCTAssertEqual(content["name"] as? String, "Safari")
        XCTAssertEqual(content["bundle_identifier"] as? String, "com.apple.Safari")
        XCTAssertEqual(content["pid"] as? Int, 12345)
    }

    func test_read_includesLocalizedDisplayName() throws {
        workspace.frontmostApplication = FrontmostApplicationInfo(
            localizedName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            processIdentifier: 12345
        )

        let content = try resource.read()

        XCTAssertEqual(content["display_name"] as? String, "Safari")
    }

    // MARK: - Scenario 5 — error path

    func test_read_returnsNoFrontmostApplicationError_whenWorkspaceReturnsNil() {
        workspace.frontmostApplication = nil

        XCTAssertThrowsError(try resource.read()) { error in
            guard case MCPError.noFrontmostApplication = error else {
                return XCTFail("Expected .noFrontmostApplication, got \(error)")
            }
        }
    }
}
