// STORY-020 — App Compatibility Catalog
// COMPONENT: DiscrepancyDetector — focused unit tests for the 3-consecutive-runs
// classification rule that CompatibilityCatalogGeneratorTests touches only at
// the edges. Persistent ⇒ build failure; singleRun ⇒ warning only.

import XCTest
@testable import MacOSControlLib

final class DiscrepancyDetectorTests: XCTestCase {

    private let scenario = "Validate interaction method selection across app types"

    func test_singleMismatch_inMostRecentRow_classifiesSingleRun() {
        let registry = registryExpectingAxFor("com.example.app")
        let observations = [
            row("com.example.app", "ax_semantic", at: "2026-05-14T10:00:00Z"),
            row("com.example.app", "ax_semantic", at: "2026-05-15T10:00:00Z"),
            row("com.example.app", "applescript", at: "2026-05-16T10:00:00Z"),
        ]

        let result = DiscrepancyDetector.find(observations: observations, registry: registry)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.kind, .singleRun)
    }

    func test_threeConsecutiveMismatches_classifyPersistent() {
        let registry = registryExpectingAxFor("com.example.app")
        let observations = [
            row("com.example.app", "applescript", at: "2026-05-14T10:00:00Z"),
            row("com.example.app", "applescript", at: "2026-05-15T10:00:00Z"),
            row("com.example.app", "applescript", at: "2026-05-16T10:00:00Z"),
        ]

        let result = DiscrepancyDetector.find(observations: observations, registry: registry)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.kind, .persistent)
    }

    func test_mismatchInterruptedByAlignedRun_classifiesSingleRun() {
        // 2 old mismatches → 1 alignment → 1 new mismatch: only the most recent
        // run is a mismatch, prior aligned run breaks persistence.
        let registry = registryExpectingAxFor("com.example.app")
        let observations = [
            row("com.example.app", "applescript", at: "2026-05-12T10:00:00Z"),
            row("com.example.app", "applescript", at: "2026-05-13T10:00:00Z"),
            row("com.example.app", "ax_semantic", at: "2026-05-14T10:00:00Z"),
            row("com.example.app", "applescript", at: "2026-05-15T10:00:00Z"),
        ]

        let result = DiscrepancyDetector.find(observations: observations, registry: registry)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.kind, .singleRun,
                       "Prior aligned run within the 3-run window breaks persistence")
    }

    func test_mostRecentRowAligned_yieldsNoDiscrepancy() {
        // Even if older rows were mismatched, a freshly aligned most-recent row
        // says the regression is gone. Don't flag.
        let registry = registryExpectingAxFor("com.example.app")
        let observations = [
            row("com.example.app", "applescript", at: "2026-05-14T10:00:00Z"),
            row("com.example.app", "applescript", at: "2026-05-15T10:00:00Z"),
            row("com.example.app", "ax_semantic", at: "2026-05-16T10:00:00Z"),
        ]

        let result = DiscrepancyDetector.find(observations: observations, registry: registry)

        XCTAssertTrue(result.isEmpty)
    }

    func test_unknownBundleId_yieldsNoDiscrepancy() {
        // Registry has no entry → no hard expectation → no discrepancy possible,
        // regardless of observed method. Matches the optimistic-attempt policy.
        let registry = FakeAppCapabilityRegistry()
        let observations = [
            row("com.unregistered.app", "coordinate_fallback",
                at: "2026-05-16T10:00:00Z")
        ]

        let result = DiscrepancyDetector.find(observations: observations, registry: registry)

        XCTAssertTrue(result.isEmpty)
    }

    func test_registryAxFalse_yieldsNoDiscrepancyForAnyObservation() {
        // Story-defined rule: only ax_supported == .yes yields a hard
        // expectation. .no / .unknown leave the router free to choose.
        let registry = FakeAppCapabilityRegistry()
        registry.stubCapability(forBundle: "com.example.electron",
                                axSupported: false, applescriptSupported: false)
        let observations = [
            row("com.example.electron", "applescript",
                at: "2026-05-16T10:00:00Z")
        ]

        let result = DiscrepancyDetector.find(observations: observations, registry: registry)

        XCTAssertTrue(result.isEmpty)
    }

    func test_groupsByBundleAndScenario_independently() {
        let registry = registryExpectingAxFor("com.example.app")
        let observations = [
            // Scenario A — three consecutive mismatches → persistent
            CompatibilityObservation(
                bundleIdentifier: "com.example.app", interactionMethod: "applescript",
                macOSVersion: "14.5", timestamp: "2026-05-14T10:00:00Z",
                scenarioName: "scenario-A"),
            CompatibilityObservation(
                bundleIdentifier: "com.example.app", interactionMethod: "applescript",
                macOSVersion: "14.5", timestamp: "2026-05-15T10:00:00Z",
                scenarioName: "scenario-A"),
            CompatibilityObservation(
                bundleIdentifier: "com.example.app", interactionMethod: "applescript",
                macOSVersion: "14.5", timestamp: "2026-05-16T10:00:00Z",
                scenarioName: "scenario-A"),
            // Scenario B — single mismatch → singleRun
            CompatibilityObservation(
                bundleIdentifier: "com.example.app", interactionMethod: "ax_semantic",
                macOSVersion: "14.5", timestamp: "2026-05-14T10:00:00Z",
                scenarioName: "scenario-B"),
            CompatibilityObservation(
                bundleIdentifier: "com.example.app", interactionMethod: "applescript",
                macOSVersion: "14.5", timestamp: "2026-05-16T10:00:00Z",
                scenarioName: "scenario-B"),
        ]

        let result = DiscrepancyDetector.find(observations: observations, registry: registry)

        XCTAssertEqual(result.count, 2)
        let kinds = Set(result.map(\.kind))
        XCTAssertTrue(kinds.contains(.persistent))
        XCTAssertTrue(kinds.contains(.singleRun))
    }

    // MARK: - Helpers

    private func registryExpectingAxFor(_ bundleId: String) -> FakeAppCapabilityRegistry {
        let r = FakeAppCapabilityRegistry()
        r.stubCapability(forBundle: bundleId, axSupported: true, applescriptSupported: true)
        return r
    }

    private func row(
        _ bundleId: String,
        _ method: String,
        at timestamp: String
    ) -> CompatibilityObservation {
        CompatibilityObservation(
            bundleIdentifier: bundleId,
            interactionMethod: method,
            macOSVersion: "14.5",
            timestamp: timestamp,
            scenarioName: scenario
        )
    }
}
