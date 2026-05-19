// STORY-012 — End-to-End Integration Validation Suite
// COMPONENT: Empirical interaction_method recorder + registry-expectation guard.
//
// DoD (STORY-020 feed): each scenario that observes an `interaction_method`
// records it to a JSON artifact, and — when the per-app capability registry has
// a definite expectation for that app — fails the scenario with a clear diff if
// the observed method contradicts it. STORY-012 produces observations;
// STORY-020 aggregates them into a maintained catalog. The two are deliberately
// decoupled: this just appends rows and enforces the local invariant.

import Foundation
import XCTest
@testable import MacOSControlLib

enum ObservationRecorder {

    /// Where rows are appended. CI sets `STORY_012_OBSERVATIONS_JSON`;
    /// otherwise a stable path under the temp dir so local runs still produce
    /// the artifact.
    static var artifactURL: URL {
        if let p = ProcessInfo.processInfo.environment["STORY_012_OBSERVATIONS_JSON"], !p.isEmpty {
            return URL(fileURLWithPath: (p as NSString).expandingTildeInPath)
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("story-012-interaction-observations.json")
    }

    struct Row: Codable {
        let scenario: String
        let tool: String
        let application: String
        let observed_interaction_method: String
        let registry_expectation: String?
        let recorded_at: String
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
        let expectation = expectedMethod(for: application, registry: registry)

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

        let row = Row(
            scenario: scenario,
            tool: tool,
            application: application,
            observed_interaction_method: observed,
            registry_expectation: expectation,
            recorded_at: ISO8601DateFormatter().string(from: Date())
        )
        append(row)
    }

    /// Maps the registry's per-layer flags to the method the router should pick
    /// first. Only `ax_supported == .yes` yields a hard expectation; anything
    /// the registry doesn't positively assert is left unconstrained (returns
    /// nil) so optimistic-fallback apps don't produce false regressions.
    static func expectedMethod(
        for bundleId: String,
        registry: AppCapabilityRegistry
    ) -> String? {
        let caps = registry.capabilities(for: bundleId)
        guard caps.source != .unknown else { return nil }
        if caps.axSupported == .yes { return "ax_semantic" }
        return nil
    }

    private static func append(_ row: Row) {
        lock.lock()
        defer { lock.unlock() }

        var rows: [Row] = []
        let url = artifactURL
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONDecoder().decode([Row].self, from: data) {
            rows = existing
        }
        rows.append(row)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(rows) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
