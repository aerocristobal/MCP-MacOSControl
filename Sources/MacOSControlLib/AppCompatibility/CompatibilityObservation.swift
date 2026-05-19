// STORY-020 — App Compatibility Catalog & Living Document
// COMPONENT: Canonical observation row shared by the STORY-012 recorder (writer)
// and the catalog generator (reader). One Codable type, one schema, one place to
// evolve. JSON keys match `docs/compatibility-observations-schema.md` verbatim.

import Foundation

/// One recorded interaction observation. Written by STORY-012's `ObservationRecorder`
/// when an integration scenario observes which interaction layer the router used
/// for a given app; read by `CompatibilityCatalogGenerator`. Optional fields
/// (`tool`, `registry_expectation`) are populated when known and omitted when not.
public struct CompatibilityObservation: Codable, Equatable, Sendable {
    public let bundleIdentifier: String
    public let interactionMethod: String      // "ax_semantic" | "applescript" | "ax_hit_test" | "coordinate_fallback"
    public let macOSVersion: String           // e.g. "14.5" — caller formats from ProcessInfo.operatingSystemVersion
    public let timestamp: String              // ISO8601 (e.g. "2026-05-19T22:33:41Z")
    public let scenarioName: String
    public let tool: String?
    public let registryExpectation: String?

    public init(
        bundleIdentifier: String,
        interactionMethod: String,
        macOSVersion: String,
        timestamp: String,
        scenarioName: String,
        tool: String? = nil,
        registryExpectation: String? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.interactionMethod = interactionMethod
        self.macOSVersion = macOSVersion
        self.timestamp = timestamp
        self.scenarioName = scenarioName
        self.tool = tool
        self.registryExpectation = registryExpectation
    }

    enum CodingKeys: String, CodingKey {
        case bundleIdentifier = "bundle_identifier"
        case interactionMethod = "interaction_method"
        case macOSVersion = "macOS_version"
        case timestamp
        case scenarioName = "scenario_name"
        case tool
        case registryExpectation = "registry_expectation"
    }
}

/// File-system I/O for the canonical observations array. Used by the STORY-012
/// recorder (append) and the STORY-020 generator/CLI (read). Atomic, deterministic
/// JSON encoding so the file is reviewable in PRs.
public enum CompatibilityObservationStore {

    /// Per-(bundle_identifier, scenario_name) retention cap. The file is committed
    /// to the repo (`docs/compatibility-observations.json`) so size matters; 50
    /// runs is roughly 7 weeks of nightly history per app/scenario, sufficient
    /// context for any human review without unbounded growth.
    public static let perKeyHistoryLimit = 50

    public static func read(from url: URL) throws -> [CompatibilityObservation] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        if data.isEmpty { return [] }
        return try JSONDecoder().decode([CompatibilityObservation].self, from: data)
    }

    public static func write(_ observations: [CompatibilityObservation], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(observations)
        try data.write(to: url, options: .atomic)
    }

    /// Append a row to the file at `url`, applying `perKeyHistoryLimit` per
    /// (bundle, scenario). Preserves chronological order based on `timestamp`.
    ///
    /// Corruption posture (DoD: "STORY-012's test failure does NOT delete
    /// prior observations"): if the file exists but decodes to something other
    /// than the expected array, we **refuse to overwrite** rather than truncate
    /// prior data — the caller surfaces the error and the maintainer repairs
    /// the file by hand. A missing file is fine (returns []) and we proceed.
    public static func append(_ observation: CompatibilityObservation, to url: URL) throws {
        var rows: [CompatibilityObservation] = []
        if FileManager.default.fileExists(atPath: url.path) {
            rows = try read(from: url)  // throws on decode failure — does not silently drop prior rows
        }
        rows.append(observation)
        rows = applyRetentionLimit(rows)
        try write(rows, to: url)
    }

    /// Visible for testing. Keep the most-recent `perKeyHistoryLimit` rows per
    /// (bundle_identifier, scenario_name). Returns the survivors in the same
    /// relative order they appeared in `rows`, so the on-disk file stays stable
    /// across appends (small diffs in PRs).
    public static func applyRetentionLimit(
        _ rows: [CompatibilityObservation]
    ) -> [CompatibilityObservation] {
        let groups = Dictionary(grouping: rows.enumerated().map { ($0.offset, $0.element) }) {
            "\($0.1.bundleIdentifier)|\($0.1.scenarioName)"
        }
        var indicesToKeep = Set<Int>()
        for (_, indexedGroup) in groups {
            // Sort by timestamp ascending; drop the oldest beyond the cap.
            let sorted = indexedGroup.sorted { $0.1.timestamp < $1.1.timestamp }
            let cutoff = max(0, sorted.count - perKeyHistoryLimit)
            for (originalIndex, _) in sorted[cutoff...] {
                indicesToKeep.insert(originalIndex)
            }
        }
        return rows.enumerated().compactMap { indicesToKeep.contains($0.offset) ? $0.element : nil }
    }
}
