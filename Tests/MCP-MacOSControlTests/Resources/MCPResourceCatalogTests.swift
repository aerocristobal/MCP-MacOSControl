// STORY: STORY-013 — MCP Resources for Ambient Context
// COMPONENT: MCPResourceCatalog

import XCTest
@testable import MacOSControlLib

final class MCPResourceCatalogTests: XCTestCase {

    func test_allResources_containsExpectedURIs() {
        let uris = Set(MCPResourceCatalog.allResources.map { $0.uri })
        XCTAssertEqual(uris, [ResourceURIs.activeApplication, ResourceURIs.activeWindowTree])
    }

    func test_activeApplication_resourceHasJsonMime() {
        let resource = MCPResourceCatalog.allResources.first { $0.uri == ResourceURIs.activeApplication }
        XCTAssertEqual(resource?.mimeType, "application/json")
    }

    func test_activeWindowTree_descriptionReferencesCurrentSchemaVersion() {
        let resource = MCPResourceCatalog.allResources.first { $0.uri == ResourceURIs.activeWindowTree }
        let description = resource?.description ?? ""
        XCTAssertTrue(description.contains("schema_version \(AXNodeSerializer.schemaVersion)"),
                      "Tree resource description must reference current AXNodeSerializer.schemaVersion dynamically")
    }

    func test_activeWindowTree_descriptionMentionsMaxDepthOverride() {
        let resource = MCPResourceCatalog.allResources.first { $0.uri == ResourceURIs.activeWindowTree }
        let description = resource?.description ?? ""
        XCTAssertTrue(description.contains("max_depth"),
                      "Tree resource description must document the max_depth override")
    }

    func test_activeApplication_descriptionMentionsErrorPath() {
        let resource = MCPResourceCatalog.allResources.first { $0.uri == ResourceURIs.activeApplication }
        let description = resource?.description ?? ""
        XCTAssertTrue(description.contains("NO_FRONTMOST_APPLICATION"),
                      "Active application description must document the no_frontmost_application error case")
    }
}
