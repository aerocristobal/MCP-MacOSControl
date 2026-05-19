// FILE: Tests/MCP-MacOSControlTests/Resources/CapabilityRegistryResourceTests.swift
// STORY: STORY-019 — Per-Application Capability Registry
// COMPONENT: CapabilityRegistryResource (MCP Resource adapter)

import XCTest
@testable import MacOSControlLib

final class CapabilityRegistryResourceTests: XCTestCase {

    var resource: CapabilityRegistryResource!
    var fakeRegistry: FakeAppCapabilityRegistry!

    override func setUp() {
        super.setUp()
        fakeRegistry = FakeAppCapabilityRegistry()
        resource = CapabilityRegistryResource(registry: fakeRegistry)
    }

    func test_resourceCatalog_includesCapabilityRegistry() {
        XCTAssertTrue(
            MCPResourceCatalog.allResources.contains { $0.uri == "mcp://capability-registry/contents" },
            "resources/list must advertise the capability registry resource"
        )
    }

    func test_read_returnsCompleteJsonDocument() throws {
        fakeRegistry.stubEntries([
            CapabilityEntry(bundleId: "com.apple.TextEdit",
                            axSupported: .yes, applescriptSupported: .yes, hitTestSupported: .yes,
                            source: .defaults)
        ])
        let payload = resource.read()
        // Serialize/parse to assert it is a valid JSON document, mirroring the
        // Server.swift ReadResource path.
        let data = try JSONSerialization.data(withJSONObject: payload)
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(parsed["schema_version"] as? Int, 1)

        // Scenario 6: the document must carry a last-modified timestamp.
        let lastModified = try XCTUnwrap(parsed["last_modified"] as? String)
        XCTAssertNotNil(ISO8601DateFormatter().date(from: lastModified),
                        "last_modified must be an ISO-8601 timestamp, got \(lastModified)")

        let entries = parsed["entries"] as? [[String: Any]] ?? []
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0]["bundle_id"] as? String, "com.apple.TextEdit")
        XCTAssertEqual(entries[0]["ax_supported"] as? Bool, true)
        XCTAssertEqual(entries[0]["applescript_supported"] as? Bool, true)
        XCTAssertEqual(entries[0]["hit_test_supported"] as? Bool, true)
        XCTAssertEqual(entries[0]["source"] as? String, "defaults")
    }

    func test_read_reflectsSchemaVersionAndOverrideSource() throws {
        fakeRegistry.schemaVersion = 2
        fakeRegistry.stubEntries([
            CapabilityEntry(bundleId: "com.electron.exampleapp",
                            axSupported: .yes, applescriptSupported: .no, hitTestSupported: .yes,
                            source: .userOverride)
        ])
        let payload = resource.read()
        XCTAssertEqual(payload["schema_version"] as? Int, 2)
        let entries = payload["entries"] as? [[String: Any]] ?? []
        XCTAssertEqual(entries.first?["source"] as? String, "user_override")
    }
}
