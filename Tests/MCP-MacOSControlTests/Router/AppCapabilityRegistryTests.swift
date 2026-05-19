// FILE: Tests/MCP-MacOSControlTests/Router/AppCapabilityRegistryTests.swift
// STORY: STORY-019 — Per-Application Capability Registry
// COMPONENT: AppCapabilityRegistry

import XCTest
@testable import MacOSControlLib

final class AppCapabilityRegistryTests: XCTestCase {

    var registry: AppCapabilityRegistry!
    var fakeDefaultsLoader: FakeBundleResourceLoader!
    var fakeOverridesLoader: FakeOverrideFileLoader!

    override func setUp() {
        super.setUp()
        fakeDefaultsLoader = FakeBundleResourceLoader()
        fakeOverridesLoader = FakeOverrideFileLoader()
        registry = AppCapabilityRegistry(defaultsLoader: fakeDefaultsLoader,
                                         overridesLoader: fakeOverridesLoader)
    }

    private func largeDefaultsFixture() -> String {
        let entries = (0..<25).map { i in
            "{\"bundle_id\": \"com.example.app\(i)\", \"ax_supported\": true, " +
            "\"applescript_supported\": false, \"hit_test_supported\": true}"
        }.joined(separator: ",\n")
        return "{\"schema_version\": 1, \"entries\": [\(entries)]}"
    }

    // MARK: - Load Defaults

    func test_loadDefaults_returnsAtLeast20Entries() throws {
        fakeDefaultsLoader.stubResource("default-app-capabilities.json",
                                        content: largeDefaultsFixture())
        try registry.load()
        XCTAssertGreaterThanOrEqual(registry.allEntries.count, 20)
    }

    func test_loadDefaults_completesWithin200ms() throws {
        fakeDefaultsLoader.stubResource("default-app-capabilities.json",
                                        content: largeDefaultsFixture())
        let start = Date()
        try registry.load()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.2)
    }

    func test_loadDefaults_recordsBooleanFlagsPerEntry() throws {
        fakeDefaultsLoader.stubResource("default-app-capabilities.json", content: """
        {"schema_version": 1, "entries": [
          {"bundle_id": "com.apple.TextEdit", "ax_supported": true,
           "applescript_supported": false, "hit_test_supported": true}
        ]}
        """)
        try registry.load()
        let caps = registry.capabilities(for: "com.apple.TextEdit")
        XCTAssertEqual(caps.axSupported, .yes)
        XCTAssertEqual(caps.applescriptSupported, .no)
        XCTAssertEqual(caps.hitTestSupported, .yes)
    }

    func test_loadDefaults_missingBundledFile_throws() {
        // No stub configured → loader throws → load() propagates (required infra).
        XCTAssertThrowsError(try registry.load())
    }

    // MARK: - Lookup

    func test_capabilities_returnsRegisteredEntry_forKnownBundleId() throws {
        fakeDefaultsLoader.stubResource("default-app-capabilities.json", content: """
        {"schema_version": 1, "entries": [
          {"bundle_id": "com.apple.TextEdit", "ax_supported": true,
           "applescript_supported": true, "hit_test_supported": true}
        ]}
        """)
        try registry.load()
        let caps = registry.capabilities(for: "com.apple.TextEdit")
        XCTAssertEqual(caps.axSupported, .yes)
        XCTAssertEqual(caps.applescriptSupported, .yes)
        XCTAssertEqual(caps.source, .defaults)
    }

    func test_capabilities_returnsUnknown_forUnregisteredBundleId() throws {
        fakeDefaultsLoader.stubResource("default-app-capabilities.json",
                                        content: "{\"schema_version\": 1, \"entries\": []}")
        try registry.load()
        let caps = registry.capabilities(for: "com.unknown.application")
        XCTAssertEqual(caps.axSupported, .unknown)
        XCTAssertEqual(caps.applescriptSupported, .unknown)
        XCTAssertEqual(caps.hitTestSupported, .unknown)
        XCTAssertEqual(caps.source, .unknown)
    }

    // MARK: - Overrides

    func test_applyOverrides_userOverrideShadowsDefault() throws {
        fakeDefaultsLoader.stubResource("default-app-capabilities.json", content: """
        {"schema_version": 1, "entries": [
          {"bundle_id": "com.electron.exampleapp", "ax_supported": false,
           "applescript_supported": false, "hit_test_supported": true}
        ]}
        """)
        fakeOverridesLoader.stubFile("overrides.json", content: """
        {"schema_version": 1, "entries": [
          {"bundle_id": "com.electron.exampleapp", "ax_supported": true,
           "applescript_supported": false, "hit_test_supported": true}
        ]}
        """)
        try registry.load()
        let caps = registry.capabilities(for: "com.electron.exampleapp")
        XCTAssertEqual(caps.axSupported, .yes)
        XCTAssertEqual(caps.source, .userOverride)
    }

    func test_applyOverrides_originalDefaultStillAccessibleViaDefaultEntry() throws {
        fakeDefaultsLoader.stubResource("default-app-capabilities.json", content: """
        {"schema_version": 1, "entries": [
          {"bundle_id": "X", "ax_supported": false, "applescript_supported": false, "hit_test_supported": false}
        ]}
        """)
        fakeOverridesLoader.stubFile("overrides.json", content: """
        {"schema_version": 1, "entries": [
          {"bundle_id": "X", "ax_supported": true, "applescript_supported": true, "hit_test_supported": true}
        ]}
        """)
        try registry.load()
        let live = registry.capabilities(for: "X")
        let original = registry.defaultEntry(for: "X")
        XCTAssertEqual(live.axSupported, .yes)
        XCTAssertEqual(original?.axSupported, .no)
    }

    // MARK: - Malformed Override

    func test_load_skipsMalformedOverrideEntries_andLogsStructuredError() throws {
        fakeDefaultsLoader.stubResource("default-app-capabilities.json",
                                        content: "{\"schema_version\": 1, \"entries\": []}")
        fakeOverridesLoader.stubFile("overrides.json", content: "{not json")
        let fakeLogger = FakeStructuredLogger()
        registry = AppCapabilityRegistry(defaultsLoader: fakeDefaultsLoader,
                                         overridesLoader: fakeOverridesLoader,
                                         logger: fakeLogger)
        XCTAssertNoThrow(try registry.load())  // does NOT crash
        XCTAssertTrue(fakeLogger.loggedErrorCodes.contains("invalid_capability_registry_override"))
        XCTAssertTrue(fakeLogger.loggedFilePaths.contains("overrides.json"))
    }

    // MARK: - Schema Extensibility

    func test_decode_acceptsUnknownFutureFields_withoutError() throws {
        fakeDefaultsLoader.stubResource("default-app-capabilities.json", content: """
        {"schema_version": 2, "entries": [
          {"bundle_id": "X", "ax_supported": true,
           "applescript_supported": false, "hit_test_supported": true,
           "drag_supported": true,            "_future_field": 42}
        ]}
        """)
        XCTAssertNoThrow(try registry.load())
        let caps = registry.capabilities(for: "X")
        XCTAssertEqual(caps.axSupported, .yes)
        XCTAssertEqual(registry.schemaVersion, 2)
    }

    // MARK: - last_modified

    func test_lastModified_reflectsMostRecentSourceMtime() throws {
        let defaultsDate = Date(timeIntervalSince1970: 1_000_000)
        let overrideDate = Date(timeIntervalSince1970: 2_000_000)  // newer
        fakeDefaultsLoader.stubResource("default-app-capabilities.json", content: """
        {"schema_version": 1, "entries": [
          {"bundle_id": "X", "ax_supported": true, "applescript_supported": true, "hit_test_supported": true}
        ]}
        """)
        fakeDefaultsLoader.stubbedModifiedAt = defaultsDate
        fakeOverridesLoader.stubFile("overrides.json", content: """
        {"schema_version": 1, "entries": [
          {"bundle_id": "Y", "ax_supported": true, "applescript_supported": true, "hit_test_supported": true}
        ]}
        """)
        fakeOverridesLoader.stubbedModifiedAt = overrideDate
        try registry.load()
        XCTAssertEqual(registry.lastModified, overrideDate)
    }

    func test_lastModified_fallsBackToLoadTime_whenNoMtimeAvailable() throws {
        fakeDefaultsLoader.stubResource("default-app-capabilities.json",
                                        content: "{\"schema_version\": 1, \"entries\": []}")
        let before = Date()
        try registry.load()
        XCTAssertGreaterThanOrEqual(registry.lastModified.timeIntervalSince1970,
                                    before.timeIntervalSince1970 - 1)
    }

    // MARK: - Shipped defaults integrity (real bundled JSON)

    func test_defaults_shippedFile_hasAtLeast20Entries() throws {
        let real = AppCapabilityRegistry(
            defaultsLoader: BundleDefaultCapabilitiesLoader(),
            overridesLoader: FakeOverrideFileLoader()
        )
        try real.load()
        XCTAssertGreaterThanOrEqual(real.allEntries.count, 20)
    }

    func test_defaults_match_Round7_outline_table() throws {
        let real = AppCapabilityRegistry(
            defaultsLoader: BundleDefaultCapabilitiesLoader(),
            overridesLoader: FakeOverrideFileLoader()
        )
        try real.load()

        let expected: [(String, CapabilityFlag, CapabilityFlag)] = [
            ("com.apple.TextEdit", .yes, .yes),
            ("com.apple.finder", .yes, .yes),
            ("com.apple.Safari", .yes, .yes),
            ("com.apple.ScriptEditor2", .yes, .yes),
            ("com.microsoft.VSCode", .yes, .no),
            ("com.tinyspeck.slackmacgap", .yes, .no),
            ("com.spotify.client", .yes, .no)
        ]
        for (bundleId, ax, applescript) in expected {
            let caps = real.capabilities(for: bundleId)
            XCTAssertEqual(caps.axSupported, ax, "ax mismatch for \(bundleId)")
            XCTAssertEqual(caps.applescriptSupported, applescript, "as mismatch for \(bundleId)")
            XCTAssertEqual(caps.source, .defaults, "source for \(bundleId)")
        }
    }
}
