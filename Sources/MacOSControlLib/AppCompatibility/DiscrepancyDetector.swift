// STORY-020 — App Compatibility Catalog
// COMPONENT: Compares observed interaction methods (from STORY-012's recorder)
// against the registry's expectation (from STORY-019). One row of mismatched
// observation = warning ("single-run"); three most-recent rows in a row for the
// same (bundle, scenario) all mismatched the same expectation = build failure
// ("persistent"). The CLI exit code keys off the latter so CI surfaces real
// drift but tolerates transient hiccups (app crash mid-test, etc.).

import Foundation

public enum DiscrepancyKind: String, Equatable, Sendable {
    case singleRun
    case persistent
}

public struct Discrepancy: Equatable, Sendable {
    public let bundleIdentifier: String
    public let scenarioName: String
    public let registryExpectation: String
    public let observedInteractionMethod: String
    public let kind: DiscrepancyKind
    public let lastObservedAt: String

    public init(
        bundleIdentifier: String,
        scenarioName: String,
        registryExpectation: String,
        observedInteractionMethod: String,
        kind: DiscrepancyKind,
        lastObservedAt: String
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.scenarioName = scenarioName
        self.registryExpectation = registryExpectation
        self.observedInteractionMethod = observedInteractionMethod
        self.kind = kind
        self.lastObservedAt = lastObservedAt
    }
}

public enum DiscrepancyDetector {

    /// How many most-recent rows must all show the same discrepancy before it is
    /// classified `.persistent`. Story-defined constant; revisit only with a new
    /// refinement round, not by hand-tuning one site.
    public static let persistentRunThreshold = 3

    /// The expectation the registry yields for `bundleId`. Mirrors the original
    /// STORY-012 rule: only `ax_supported == .yes` produces a hard expectation;
    /// anything the registry doesn't positively assert yields `nil` (the router
    /// is free to pick any layer, no false regression).
    public static func expectedMethod(
        for bundleId: String,
        registry: CapabilityRegistryReading
    ) -> String? {
        guard let entry = registry.allEntries.first(where: { $0.bundleId == bundleId }) else {
            return nil
        }
        guard entry.source != .unknown else { return nil }
        if entry.axSupported == .yes { return "ax_semantic" }
        return nil
    }

    /// Find every discrepancy across `observations`, classified by recency rule.
    public static func find(
        observations: [CompatibilityObservation],
        registry: CapabilityRegistryReading
    ) -> [Discrepancy] {
        var results: [Discrepancy] = []
        let groups = Dictionary(grouping: observations) {
            "\($0.bundleIdentifier)|\($0.scenarioName)"
        }
        // Deterministic order across runs — sorted by group key.
        for key in groups.keys.sorted() {
            guard let rows = groups[key], let first = rows.first else { continue }
            guard let expectation = expectedMethod(for: first.bundleIdentifier, registry: registry) else {
                continue
            }
            let sorted = rows.sorted { $0.timestamp > $1.timestamp }   // most-recent first
            guard let mostRecent = sorted.first, mostRecent.interactionMethod != expectation else {
                continue
            }
            let recentN = sorted.prefix(persistentRunThreshold)
            let allRecentDiscrepant = recentN.count >= persistentRunThreshold
                && recentN.allSatisfy { $0.interactionMethod != expectation }
            results.append(Discrepancy(
                bundleIdentifier: first.bundleIdentifier,
                scenarioName: first.scenarioName,
                registryExpectation: expectation,
                observedInteractionMethod: mostRecent.interactionMethod,
                kind: allRecentDiscrepant ? .persistent : .singleRun,
                lastObservedAt: mostRecent.timestamp
            ))
        }
        return results
    }
}
