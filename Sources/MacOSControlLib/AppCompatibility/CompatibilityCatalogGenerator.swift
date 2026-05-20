// STORY-020 — App Compatibility Catalog & Living Document
// COMPONENT: Produces `docs/APP-COMPATIBILITY.md` from observed interaction
// methods (STORY-012's recorder) + registry expectations (STORY-019). Pure
// string generation — no markdown library dependency. Clock-driven cutoffs so
// FakeClock can drive deterministic tests.

import Foundation

#if canImport(AppKit)
import AppKit
#endif

public struct VersionMatrix: Equatable, Sendable {
    /// All macOS versions seen across the observations, lexicographic order.
    public let versions: [String]
    /// For each version, the bundle ids that have at least one observation on it.
    public let bundlesByVersion: [String: [String]]
}

public struct StaleReport: Equatable, Sendable {
    public let staleBundleIds: Set<String>
    public let archivedBundleIds: Set<String>
}

public struct GeneratorResult: Sendable {
    public let markdown: String
    public let discrepancies: [Discrepancy]
}

public final class CompatibilityCatalogGenerator: @unchecked Sendable {

    /// Story-defined cutoffs (story-020 §9 / Three Amigos resolution).
    public static let staleAfterDays = 90
    public static let archiveAfterDays = 180

    private let clock: Clock

    public init(clock: Clock = SystemClock()) {
        self.clock = clock
    }

    // MARK: - Public API

    public func generate(
        observations: [CompatibilityObservation],
        registry: CapabilityRegistryReading
    ) throws -> String {
        try generateWithDiscrepancyAnalysis(observations: observations, registry: registry).markdown
    }

    public func generateWithDiscrepancyAnalysis(
        observations: [CompatibilityObservation],
        registry: CapabilityRegistryReading
    ) throws -> GeneratorResult {
        let discrepancies = DiscrepancyDetector.find(observations: observations, registry: registry)
        let stale = staleReport(observations: observations)
        let active = activeBundles(observations: observations, exclude: stale.archivedBundleIds)
        let archived = archivedBundles(observations: observations, archivedBundleIds: stale.archivedBundleIds)
        let matrix = buildVersionMatrix(observations: observations)

        var md = ""
        md += "# App Compatibility Catalog\n\n"
        md += "_Generated artifact — do not edit by hand. Source data: `docs/compatibility-observations.json`._\n\n"
        md += "- Last regenerated: \(iso8601Date(clock.now()))\n"
        md += "- Total apps: \(active.count + archived.count)\n"
        md += "- Active apps: \(active.count)\n"
        md += "- Archived apps: \(archived.count)\n"
        md += "- Discrepancies (persistent): \(discrepancies.filter { $0.kind == .persistent }.count)\n"
        md += "- Discrepancies (single-run): \(discrepancies.filter { $0.kind == .singleRun }.count)\n"
        if matrix.versions.isEmpty {
            md += "- macOS versions exercised: _(none yet)_\n\n"
        } else {
            md += "- macOS versions exercised: \(matrix.versions.joined(separator: ", "))\n\n"
        }

        if !discrepancies.isEmpty {
            md += "## Discrepancies\n\n"
            md += "| bundle_identifier | scenario | registry_expects | observed | kind | last_observed |\n"
            md += "|---|---|---|---|---|---|\n"
            for d in discrepancies {
                md += "| \(d.bundleIdentifier) | \(d.scenarioName) | \(d.registryExpectation) | \(d.observedInteractionMethod) | \(d.kind.rawValue) | \(d.lastObservedAt) |\n"
            }
            md += "\n"
        }

        md += "## Active applications\n\n"
        md += "| bundle_identifier | localized_name | observed_interaction_methods | registry_expectation | macOS_version_tested | last_verified_date | notes |\n"
        md += "|---|---|---|---|---|---|---|\n"
        if active.isEmpty {
            md += "| _(no active observations)_ | | | | | | |\n"
        } else {
            let discrepantBundles = Set(discrepancies.map(\.bundleIdentifier))
            for row in active {
                let expectation = DiscrepancyDetector.expectedMethod(
                    for: row.bundleIdentifier, registry: registry
                ) ?? "—"
                var notes: [String] = []
                if discrepantBundles.contains(row.bundleIdentifier) {
                    notes.append("⚠️ discrepancy")
                }
                if stale.staleBundleIds.contains(row.bundleIdentifier) {
                    notes.append("stale (>\(Self.staleAfterDays)d)")
                }
                let notesCell = notes.isEmpty ? "" : notes.joined(separator: ", ")
                md += "| \(row.bundleIdentifier)"
                md += " | \(row.localizedName)"
                md += " | \(row.observedMethods.joined(separator: ", "))"
                md += " | \(expectation)"
                md += " | \(row.macOSVersions.joined(separator: ", "))"
                md += " | \(row.lastVerifiedDate)"
                md += " | \(notesCell) |\n"
            }
        }
        md += "\n"

        md += "## macOS version matrix\n\n"
        if matrix.versions.isEmpty {
            md += "_No observations recorded yet._\n\n"
        } else {
            md += "| bundle_identifier | " + matrix.versions.joined(separator: " | ") + " |\n"
            md += "|---" + String(repeating: "|---", count: matrix.versions.count) + "|\n"
            let allBundles = Set(observations.map(\.bundleIdentifier)).sorted()
            for bundle in allBundles {
                var row = "| \(bundle) |"
                for version in matrix.versions {
                    let observed = matrix.bundlesByVersion[version]?.contains(bundle) ?? false
                    row += " \(observed ? "✅" : "—") |"
                }
                md += row + "\n"
            }
            md += "\n"
        }

        md += "## Archived (no observations in \(Self.archiveAfterDays)+ days)\n\n"
        if archived.isEmpty {
            md += "_No archived applications._\n\n"
        } else {
            md += "| bundle_identifier | last_observed_interaction_method | macOS_version | last_observed |\n"
            md += "|---|---|---|---|\n"
            for row in archived {
                md += "| \(row.bundleIdentifier) | \(row.observedMethods.joined(separator: ", ")) | \(row.macOSVersions.joined(separator: ", ")) | \(row.lastVerifiedDate) |\n"
            }
            md += "\n"
        }

        md += "---\n\n"
        md += "_Registry source-of-truth: [`Sources/MacOSControlLib/Router/Defaults/default-app-capabilities.json`](../Sources/MacOSControlLib/Router/Defaults/default-app-capabilities.json) — see [STORY-019](stories/STORY-019-per-app-capability-registry.md). "
        md += "Observation source: [`docs/compatibility-observations.json`](compatibility-observations.json), populated by the [STORY-012](stories/STORY-012-end-to-end-integration-validation.md) integration suite._\n"

        return GeneratorResult(markdown: md, discrepancies: discrepancies)
    }

    /// Public for tests. All distinct macOS versions present in `observations`,
    /// sorted lexicographically, plus the per-version bundle index.
    public func buildVersionMatrix(observations: [CompatibilityObservation]) -> VersionMatrix {
        var bundlesByVersion: [String: Set<String>] = [:]
        for o in observations {
            bundlesByVersion[o.macOSVersion, default: []].insert(o.bundleIdentifier)
        }
        let versions = bundlesByVersion.keys.sorted()
        let bundlesArrays = bundlesByVersion.mapValues { $0.sorted() }
        return VersionMatrix(versions: versions, bundlesByVersion: bundlesArrays)
    }

    /// Public for tests. A bundle is **stale** when its most-recent observation
    /// is older than `staleAfterDays`; **archived** when older than `archiveAfterDays`.
    /// Archived ⊃ stale conceptually, but the report sets are disjoint so the
    /// caller can pick which section a bundle belongs in without rechecking.
    public func staleReport(observations: [CompatibilityObservation]) -> StaleReport {
        let now = clock.now()
        let staleCutoff = now.addingTimeInterval(-Double(Self.staleAfterDays) * 86_400)
        let archiveCutoff = now.addingTimeInterval(-Double(Self.archiveAfterDays) * 86_400)
        var lastSeen: [String: Date] = [:]
        for o in observations {
            guard let t = parseISO8601(o.timestamp) else { continue }
            lastSeen[o.bundleIdentifier] = max(lastSeen[o.bundleIdentifier] ?? .distantPast, t)
        }
        var stale = Set<String>()
        var archived = Set<String>()
        for (bundle, last) in lastSeen {
            if last < archiveCutoff {
                archived.insert(bundle)
            } else if last < staleCutoff {
                stale.insert(bundle)
            }
        }
        return StaleReport(staleBundleIds: stale, archivedBundleIds: archived)
    }

    public func staleRowReport(observations: [CompatibilityObservation]) -> StaleReport {
        staleReport(observations: observations)
    }

    /// Render the active-section row for a single bundle. Useful for snapshot
    /// tests that want to assert a single app's appearance without parsing the
    /// whole document.
    public func appSection(
        _ bundleId: String,
        observations: [CompatibilityObservation],
        registry: CapabilityRegistryReading
    ) -> String {
        let scoped = observations.filter { $0.bundleIdentifier == bundleId }
        guard let row = buildBundleRows(from: scoped).first else {
            return "No observations for \(bundleId)."
        }
        let expectation = DiscrepancyDetector.expectedMethod(for: bundleId, registry: registry) ?? "—"
        return "\(row.bundleIdentifier) [\(row.localizedName)] — observed: \(row.observedMethods.joined(separator: ", ")) — registry: \(expectation) — versions: \(row.macOSVersions.joined(separator: ", ")) — last: \(row.lastVerifiedDate)"
    }

    // MARK: - Internals

    private struct BundleRow {
        let bundleIdentifier: String
        let localizedName: String
        let observedMethods: [String]    // sorted, deduped
        let macOSVersions: [String]      // sorted, deduped
        let lastVerifiedDate: String     // ISO8601
    }

    private func activeBundles(
        observations: [CompatibilityObservation],
        exclude archivedBundleIds: Set<String>
    ) -> [BundleRow] {
        let scoped = observations.filter { !archivedBundleIds.contains($0.bundleIdentifier) }
        return buildBundleRows(from: scoped)
    }

    private func archivedBundles(
        observations: [CompatibilityObservation],
        archivedBundleIds: Set<String>
    ) -> [BundleRow] {
        let scoped = observations.filter { archivedBundleIds.contains($0.bundleIdentifier) }
        return buildBundleRows(from: scoped)
    }

    private func buildBundleRows(from observations: [CompatibilityObservation]) -> [BundleRow] {
        let groups = Dictionary(grouping: observations, by: \.bundleIdentifier)
        return groups.keys.sorted().compactMap { bundle in
            guard let rows = groups[bundle], !rows.isEmpty else { return nil }
            let methods = Array(Set(rows.map(\.interactionMethod))).sorted()
            let versions = Array(Set(rows.map(\.macOSVersion))).sorted()
            let latest = rows.map(\.timestamp).max() ?? ""
            return BundleRow(
                bundleIdentifier: bundle,
                localizedName: localizedName(forBundleId: bundle),
                observedMethods: methods,
                macOSVersions: versions,
                lastVerifiedDate: latest
            )
        }
    }

    /// Best-effort localized name lookup. Pure & headless when the app is not
    /// installed on the catalog-generating machine — falls back to the bundle id
    /// so generation never blocks on missing apps (e.g. running in CI under a
    /// minimal user account, or someone running the generator on an old laptop).
    private func localizedName(forBundleId bundleId: String) -> String {
        #if canImport(AppKit) && !os(Linux)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: url),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        #endif
        return bundleId
    }

    private func iso8601Date(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: d)
    }

    private func parseISO8601(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: s) { return d }
        // Also accept date-only timestamps written by fixture authors.
        let dateOnly = ISO8601DateFormatter()
        dateOnly.formatOptions = [.withFullDate]
        return dateOnly.date(from: s)
    }
}
