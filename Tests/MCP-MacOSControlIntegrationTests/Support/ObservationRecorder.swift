// STORY-012 — End-to-End Integration Validation Suite
// COMPONENT: Empirical interaction_method recorder + registry-expectation guard.
//
// STORY-020 migrated this recorder onto the canonical `CompatibilityObservation`
// schema (bundle_identifier / interaction_method / macOS_version / timestamp /
// scenario_name) and switched the default sink to `docs/compatibility-observations.json`
// so the integration suite writes directly into the committed living-data file
// that the catalog generator consumes. CI may still redirect via the
// `STORY_012_OBSERVATIONS_JSON` env var when it wants to capture an artifact
// without touching the repo checkout (e.g. read-only checkouts on hosted runners).
//
// DoD (STORY-020 feed): each scenario that observes an `interaction_method`
// records it to the shared JSON file, and — when the per-app capability
// registry has a definite expectation for that app — fails the scenario with a
// clear diff if the observed method contradicts it. STORY-020 then aggregates
// these rows into the maintained catalog (`docs/APP-COMPATIBILITY.md`).

import Foundation
import XCTest
@testable import MacOSControlLib

enum ObservationRecorder {

    /// Where rows are appended. CI may override via `STORY_012_OBSERVATIONS_JSON`
    /// (e.g. point at an artifact path). Otherwise we resolve the repo's
    /// committed `docs/compatibility-observations.json` from `#filePath` —
    /// works whether the integration tests are running from a fresh checkout
    /// or a developer's clone, with no env-var configuration required.
    static var artifactURL: URL {
        if let p = ProcessInfo.processInfo.environment["STORY_012_OBSERVATIONS_JSON"], !p.isEmpty {
            return URL(fileURLWithPath: (p as NSString).expandingTildeInPath)
        }
        return repoCanonicalObservationsURL()
    }

    /// Resolve `<repo-root>/docs/compatibility-observations.json` by walking
    /// up from this source file. Layout-stable for as long as this file lives
    /// under `Tests/MCP-MacOSControlIntegrationTests/Support/`.
    private static func repoCanonicalObservationsURL(filePath: String = #filePath) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent() // Support
            .deletingLastPathComponent() // MCP-MacOSControlIntegrationTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // <repo-root>
            .appendingPathComponent("docs")
            .appendingPathComponent("compatibility-observations.json")
    }

    private static let lock = NSLock()

    /// Append one observation and enforce the registry-expectation invariant.
    /// `application` is a bundle id when known; expectation only applies when
    /// the registry has a non-`unknown` row for it.
    static func record(
        scenario: String,
        tool: String,
        application: String,
        observed: String,
        registry: AppCapabilityRegistry,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = DiscrepancyDetector.expectedMethod(for: application, registry: registry)

        if let expectation, expectation != observed {
            XCTFail(
                """
                interaction_method regression for \(application) in "\(scenario)": \
                registry expects "\(expectation)" but the tool used "\(observed)". \
                Either the app's real capabilities changed (update \
                default-app-capabilities.json) or a routing regression slipped in.
                """,
                file: file, line: line
            )
        }

        let observation = CompatibilityObservation(
            bundleIdentifier: application,
            interactionMethod: observed,
            macOSVersion: currentMacOSVersion(),
            timestamp: ISO8601DateFormatter().string(from: Date()),
            scenarioName: scenario,
            tool: tool,
            registryExpectation: expectation
        )
        append(observation)
    }

    /// "<major>.<minor>" — coarser than `operatingSystemVersionString` (which
    /// carries the patch + build) so version-matrix groupings stay stable across
    /// patch-level CI runners.
    private static func currentMacOSVersion() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion)"
    }

    private static func append(_ observation: CompatibilityObservation) {
        lock.lock()
        defer { lock.unlock() }
        do {
            try CompatibilityObservationStore.append(observation, to: artifactURL)
        } catch {
            XCTFail("ObservationRecorder failed to append: \(error)")
        }
    }
}
