# STORY-019 — Per-Application Capability Registry

**Epic:** EPIC-6 · Agent Interaction Hierarchy
**Priority:** 🟡 High
**Story Points:** 2
**Sprint Target:** Sprint 4 (must precede STORY-010)
**Dependencies:** 🔒 STORY-016 (Structured Error Response Contract)
**Refinement Round:** 7 — Newly added during Epic 6 refinement. Carves the "which layers work for which app" data layer out of STORY-010 so the router consumes a clean, testable, user-overridable registry.

---

## 1. User Story Narrative

```
Story: Per-Application Capability Registry
In order to skip interaction layers known to fail for specific applications
As an operator of the MCP server
I want a registry of per-app layer capabilities that the smart_interact router consults before each attempt
So that interactions with notoriously broken apps (Electron, web-based UIs) avoid wasted time and noisy logs by skipping straight to the layer that works
```

**Additional Context:** Real-world macOS apps have wildly uneven interaction support. Native Cocoa apps (TextEdit, Finder, Safari) have good AX trees. Electron apps (VS Code, Slack, Discord) have technically-present-but-mostly-useless AX trees. Java apps (some JetBrains IDEs) used to have no AX; now have partial AX. AppleScript dictionaries are even more uneven — about 30% of macOS apps ship one, and the quality varies. Without a registry, `smart_interact` (STORY-010) has to attempt every layer optimistically for every app, paying a wall-clock and log-noise cost on apps where the first layer is known to fail. A small declarative registry — shipped with sane defaults, overridable per-user, surfaced as MCP-readable — fixes this. This story is foundational data infrastructure consumed by STORY-010 and reportable via STORY-020.

---

## 2. Acceptance Criteria (BDD Scenarios)

```gherkin
@epic-6 @story-019 @data-layer
Feature: Per-Application Capability Registry
  In order to make smart routing decisions data-driven
  As the smart_interact router (and operators inspecting routing decisions)
  I want a registry of per-app layer capabilities loaded at server startup

  Background:
    Given the MCP server is running

  Scenario: Registry loads default entries at server startup
    When the MCP server starts
    Then the in-memory registry contains entries for at least 20 well-known macOS bundle identifiers
    And each entry records boolean flags for ax_supported, applescript_supported, hit_test_supported
    And the load completes within 200 milliseconds

  Scenario: Lookup returns layer capabilities for a known bundle identifier
    Given the registry contains an entry for "com.apple.TextEdit" with ax_supported=true, applescript_supported=true
    When the router queries the registry for bundle_id "com.apple.TextEdit"
    Then the result includes ax_supported = true
    And the result includes applescript_supported = true
    And the result includes a non-empty "source" field naming where the entry came from

  Scenario: Lookup returns "unknown" for unregistered bundle identifiers
    Given no entry exists for bundle_id "com.unknown.application"
    When the router queries the registry for bundle_id "com.unknown.application"
    Then the result indicates capabilities are unknown
    And the router treats unknown apps as optimistically supporting all layers

  Scenario: User overrides shadow default entries
    Given the default registry has "com.electron.exampleapp" with ax_supported=false
    And the user override file marks "com.electron.exampleapp" with ax_supported=true
    When the registry is reloaded with the override applied
    Then the lookup for "com.electron.exampleapp" returns ax_supported = true
    And the result's "source" field reads "user_override"
    And the original default entry remains accessible via registry.defaultEntry(for:)

  Scenario: Reject malformed override file with a clear error
    Given a user override file contains a syntactically invalid JSON entry
    When the registry attempts to load it at startup
    Then the server logs a structured error with error_code "invalid_capability_registry_override"
    And the malformed entries are skipped
    And the server starts successfully using only the default entries
    And the error message identifies the offending file path and line number when available

  Scenario: Registry exposes its contents via an MCP Resource
    Given the registry is loaded
    When an MCP client lists Resources
    Then a resource "mcp://capability-registry/contents" is available
    And reading that resource returns a JSON document with every entry, its source, and last-modified timestamp

  Scenario: Capability fields are extensible without breaking existing consumers
    Given the v1 registry schema defines fields: ax_supported, applescript_supported, hit_test_supported
    When a future v2 entry adds a new boolean field "drag_supported"
    Then existing consumers querying only v1 fields continue to function unchanged
    And the registry schema_version field reflects v2
    And the MCP Resource response includes the schema_version

  Scenario Outline: Known macOS apps have sensible default capabilities
    Given the default registry shipped with the server
    When the registry is queried for <bundle_id>
    Then the result has ax_supported = <ax>
    And the result has applescript_supported = <as>

    Examples:
      | bundle_id                      | ax    | as    |
      | com.apple.TextEdit             | true  | true  |
      | com.apple.finder               | true  | true  |
      | com.apple.Safari               | true  | true  |
      | com.apple.ScriptEditor2        | true  | true  |
      | com.microsoft.VSCode           | true  | false |
      | com.tinyspeck.slackmacgap      | true  | false |
      | com.spotify.client             | true  | false |
```

---

## 3. Scenario Coverage Checklist

| Coverage Type | Scenario(s) | Status |
|---|---|---|
| Main success path | Registry loads; lookup returns known entry | ✅ |
| Alternative success path | User override shadows defaults; MCP Resource exposes contents | ✅ |
| Boundary condition | Unknown bundle → "unknown" capabilities; schema extensibility forward-compatible | ✅ |
| Error / rejection path | Malformed override doesn't crash startup; structured error logged | ✅ |
| Business rule edge case | Outline of well-known apps codifies the defaults to ship with | ✅ |

---

## 4. Three Amigos Open Questions (Round 7)

| # | Question | Resolution |
|---|---|---|
| Q1 | Default registry — where does it live? Compiled-in or shipped as a file? | **Shipped as `Resources/default-app-capabilities.json` inside the Swift package bundle.** Compiled-in is opaque to ops; standalone file is editable and inspectable. Bundle resource loaded at startup. _[NEEDS CONFIRMATION]_ |
| Q2 | User override location? | **`~/.config/mcp-macos-control/app-overrides.json`** with `MCP_MACOS_CONTROL_OVERRIDES_PATH` env var to redirect. Follows XDG conventions; consistent with macOS Cocoa-app config patterns. _[NEEDS CONFIRMATION]_ |
| Q3 | Should the registry support per-version capabilities (e.g., Slack 4.x has bad AX, Slack 5.x has good AX)? | **No at v1.** Adds JSON complexity for marginal real-world payoff. Override file allows users to swap by hand if needed. Revisit if telemetry from STORY-020 shows version-bound mismatches are common. |
| Q4 | What fields beyond the three booleans? | **v1: three booleans only.** Resist temptation to add `preferred_layer`, `last_verified_date`, `notes`. Each new field is a maintenance burden. Add later if STORY-020's catalog operations demonstrate need. |
| Q5 | How is the registry kept up to date with reality? | **Through STORY-020's compatibility catalog work.** STORY-020 runs `smart_interact` against the well-known app list and updates the default JSON file. This story produces the *infrastructure*; STORY-020 produces the *content discipline*. |
| Q6 | What about catch-all rules — e.g., "any bundle id matching `com.electron.*` defaults to ax_supported=false"? | **No wildcards at v1.** Wildcard precedence rules are a separate complexity. List individual bundle ids; rely on STORY-020 to keep the list current. _[NEEDS CONFIRMATION]_ |
| Q7 | Hot-reload of the override file without server restart? | **No at v1.** Server-restart-on-change is the safer semantic. File-watch with debounce can be added later if real ops needs surface. |

---

## 5. TDD Implementation Map

| BDD Scenario | Step | Step Type | Unit Under Test | TDD Test Cases Required |
|---|---|---|---|---|
| Registry loads at startup | When server starts | When | `AppCapabilityRegistry.loadDefaults()` | test_loadsDefaults_returnsAtLeast20Entries, test_loadCompletesWithin200ms |
| Lookup returns known entry | When lookup called | When | `AppCapabilityRegistry.capabilities(for:)` | test_returnsRegisteredCapabilities_forKnownBundleId, test_resultIncludesSourceField |
| Unknown bundle | Then result indicates unknown | Then | `AppCapabilityRegistry.capabilities(for:)` | test_returnsUnknownCapabilities_forUnregisteredBundleId, test_unknownTreatedAsOptimisticByConsumer |
| Override shadows default | When overrides loaded | When | `AppCapabilityRegistry.applyOverrides(_:)` | test_userOverrideShadowsDefault, test_sourceFieldReportsUserOverride, test_defaultEntryStillAccessible |
| Malformed override | Given invalid JSON | Given | `OverrideFileLoader.load(_:)` | test_skipsInvalidEntries, test_logsStructuredError_invalid_capability_registry_override |
| MCP Resource exposure | When client lists resources | When | `CapabilityRegistryResource` | test_resourceListIncludesCapabilityRegistry, test_resourceReadReturnsCompleteJsonDocument |
| Schema extensibility | When v2 field present | When | `CapabilityEntry.decode(from:)` | test_decodesV1EntryWithUnknownV2Fields_withoutError, test_emitsSchemaVersionInResourceResponse |
| Default entries outline | Each well-known app | When | `AppCapabilityRegistry.capabilities(for:)` | test_defaults_match_Round7_outline_table |

---

## 6. TDD Unit Test Scaffolds

### 6.1 `AppCapabilityRegistry`

```swift
// FILE: Tests/MCP-MacOSControlTests/Router/AppCapabilityRegistryTests.swift
// STORY: STORY-019 — Per-Application Capability Registry
// COMPONENT: AppCapabilityRegistry

import XCTest
@testable import MacOSControlLib

final class AppCapabilityRegistryTests: XCTestCase {

    var registry: AppCapabilityRegistry!
    var fakeDefaultsLoader: FakeBundleResourceLoader!
    var fakeOverridesLoader: FakeFileLoader!

    override func setUp() {
        super.setUp()
        fakeDefaultsLoader = FakeBundleResourceLoader()
        fakeOverridesLoader = FakeFileLoader()
        registry = AppCapabilityRegistry(defaultsLoader: fakeDefaultsLoader,
                                         overridesLoader: fakeOverridesLoader)
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
        XCTAssertTrue(caps.axSupported == .yes)
        XCTAssertTrue(caps.applescriptSupported == .yes)
        XCTAssertEqual(caps.source, .defaults)
    }

    func test_capabilities_returnsUnknown_forUnregisteredBundleId() throws {
        try registry.load()
        let caps = registry.capabilities(for: "com.unknown.application")
        XCTAssertEqual(caps.axSupported, .unknown)
        XCTAssertEqual(caps.applescriptSupported, .unknown)
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
        fakeDefaultsLoader.stubResource("default-app-capabilities.json", content: """
        {"schema_version": 1, "entries": []}
        """)
        fakeOverridesLoader.stubFile("overrides.json", content: "{not json")
        let fakeLogger = FakeStructuredLogger()
        registry = AppCapabilityRegistry(defaultsLoader: fakeDefaultsLoader,
                                         overridesLoader: fakeOverridesLoader,
                                         logger: fakeLogger)
        XCTAssertNoThrow(try registry.load())  // does NOT crash
        XCTAssertTrue(fakeLogger.loggedErrorCodes.contains("invalid_capability_registry_override"))
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
    }
}
```

### 6.2 `CapabilityRegistryResource` (MCP Resource adapter)

```swift
// FILE: Tests/MCP-MacOSControlTests/Resources/CapabilityRegistryResourceTests.swift
// STORY: STORY-019 — Per-Application Capability Registry
// COMPONENT: CapabilityRegistryResource

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

    func test_listResources_includesCapabilityRegistry() async {
        let listed = await resource.list()
        XCTAssertTrue(listed.contains { $0.uri == "mcp://capability-registry/contents" })
    }

    func test_readResource_returnsCompleteJsonDocument() async throws {
        fakeRegistry.stubEntries([
            CapabilityEntry(bundleId: "com.apple.TextEdit",
                            axSupported: .yes, applescriptSupported: .yes, hitTestSupported: .yes,
                            source: .defaults)
        ])
        let content = try await resource.read(uri: "mcp://capability-registry/contents")
        let parsed = try JSONSerialization.jsonObject(with: content.data(using: .utf8)!) as! [String: Any]
        XCTAssertEqual(parsed["schema_version"] as? Int, 1)
        let entries = parsed["entries"] as? [[String: Any]] ?? []
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0]["bundle_id"] as? String, "com.apple.TextEdit")
    }
}
```

---

## 7. Dependencies & Test Doubles

| Dependency | Type | Source | Notes |
|---|---|---|---|
| Bundle resource loader | Standard library | `FakeBundleResourceLoader` | Reads `default-app-capabilities.json` from the package's `Resources/` directory |
| File loader for overrides | Standard library | `FakeFileLoader` | Reads `~/.config/mcp-macos-control/app-overrides.json` |
| `StructuredLogger` (existing) | Real | `FakeStructuredLogger` | Logs malformed-override errors |
| MCP Resources framework (STORY-013) | Real | Existing fakes | `CapabilityRegistryResource` conforms to the MCP Resource protocol shipped in STORY-013 |
| `ErrorCodeRegistry` (STORY-016) | Real | No double | Registers `invalid_capability_registry_override` |

---

## 8. Definition of Done

**Data layer**
- [ ] `AppCapabilityRegistry` actor type in `Sources/MacOSControlLib/Router/`
- [ ] Default entries file: `Resources/default-app-capabilities.json` with ≥ 20 well-known macOS bundle identifiers
- [ ] JSON schema documented in the file's leading comment: `schema_version`, `entries[]`, fields per entry
- [ ] User override file path: `~/.config/mcp-macos-control/app-overrides.json` (env override: `MCP_MACOS_CONTROL_OVERRIDES_PATH`)
- [ ] Override loading is fail-soft: malformed entries are skipped, server still starts

**Lookup contract**
- [ ] `capabilities(for: BundleIdentifier) -> CapabilitiesResult` always returns a value (never nil); unknown apps return `.unknown` for all fields
- [ ] Result includes a `source` field (`.defaults`, `.userOverride`, `.unknown`)
- [ ] `defaultEntry(for:)` preserves access to the unshadowed default

**MCP Resource integration (STORY-013)**
- [ ] Resource URI: `mcp://capability-registry/contents`
- [ ] Read returns the full JSON document with `schema_version` and `entries[]`
- [ ] Resource conforms to the MCP Resource protocol from STORY-013

**Error contract registered with STORY-016**
- [ ] `invalid_capability_registry_override` — details include offending file path and (when available) line number

**Performance**
- [ ] Load completes within 200 ms for the shipped defaults
- [ ] Lookup is O(1) (hash-map indexed by bundle id)

**Tests**
- [ ] All BDD scenarios pass in CI
- [ ] Unit coverage ≥ 90% on `AppCapabilityRegistry` (small surface — high coverage cheap)
- [ ] Test fixture file with intentional malformed entries covered by failing-fast tests
- [ ] Living documentation generator maps every scenario to ≥ 1 unit test

**Documentation**
- [ ] `docs/stories/STORY-019-per-app-capability-registry.md` (this file) committed
- [ ] `Tests/MCP-MacOSControlTests/Features/story-019-per-app-capability-registry.feature` committed
- [ ] README updated: section explaining capability overrides for power users
- [ ] `default-app-capabilities.json` cross-referenced from STORY-020 catalog

---

## 9. Notes & Observations

- **Why is this its own story instead of a slice of STORY-010?** Same reason STORY-001 was its own foundation story: clean separation of concerns + independent shippability + a stable contract for downstream consumers. STORY-010 can be tested with a `FakeAppCapabilityRegistry` and not block on this story's data work. This story can be tested without the router existing. And the registry has independent value as an MCP Resource for any client that wants to inspect routing decisions.
- **Why ≥ 20 default entries?** Not arbitrary. The macOS apps people actually drive AI agents against — TextEdit, Finder, Safari, Mail, Calendar, Notes, Reminders, Messages, FaceTime, Photos, Pages, Keynote, Numbers, Preview, Terminal, Script Editor, Activity Monitor, System Settings, Calculator, App Store — easily reach 20 from Apple's first-party apps alone, plus common third-party (VS Code, Slack, Chrome, Firefox, Zoom). Anything less and the registry feels like a stub. _[NEEDS CONFIRMATION: exact list of 20 in the initial JSON file]_
- **Why no wildcard rules (`com.electron.*`)?** Bundle-id matching is intent-revealing: someone reading the JSON should see exactly which apps are classified how. Wildcards hide which apps you've actually tested vs which apps you've inferred. STORY-020's catalog discipline depends on the explicit list.
- **Why expose as an MCP Resource?** Two reasons: (a) operators inspecting why their agent fell back to a coordinate click can fetch the resource and see what the registry said; (b) tooling that wants to compare registry claims against observed reality (STORY-020) has a stable read API.
- **Failure semantics:** Default-loading failure crashes the server (registry is required infrastructure). Override-loading failure is non-fatal — server starts with defaults only. This asymmetry is deliberate: shipped defaults are a build-time guarantee; user overrides are best-effort.
- **Why is this only 2 points?** Small surface, pure data layer, no concurrency complexity, no AX C-API. Most of the story is the test fixtures and the careful Round 7 outline data.
