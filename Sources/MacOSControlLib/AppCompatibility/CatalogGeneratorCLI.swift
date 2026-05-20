// STORY-020 — App Compatibility Catalog CLI
// COMPONENT: Argument-free entry point exercised by tests + the executable
// target `mcp-macos-control-catalog`. Reads observation + registry JSON, runs
// the generator, writes the Markdown, returns an exit code. Single-run
// discrepancies → exit 0 (warn on stderr); persistent discrepancies → exit 2
// (CI fails). The split between this function and the executable's `main.swift`
// is deliberate: tests drive `run(observationsPath:registryPath:outputPath:)`
// directly, without spawning a subprocess and parsing argv.

import Foundation

public enum CatalogGeneratorCLI {

    /// Exit codes (mirrors typical CLI conventions; values are part of the
    /// contract checked by CI).
    public enum ExitCode {
        public static let ok: Int32 = 0
        public static let usage: Int32 = 64        // sysexits.h EX_USAGE
        public static let dataError: Int32 = 65    // sysexits.h EX_DATAERR
        public static let persistentDiscrepancy: Int32 = 2
    }

    public static func run(
        observationsPath: URL,
        registryPath: URL,
        outputPath: URL,
        clock: Clock = SystemClock()
    ) async -> Int32 {
        do {
            let observations = try CompatibilityObservationStore.read(from: observationsPath)
            let registry = try loadRegistry(from: registryPath)
            let generator = CompatibilityCatalogGenerator(clock: clock)
            let result = try generator.generateWithDiscrepancyAnalysis(
                observations: observations,
                registry: registry
            )
            try writeMarkdown(result.markdown, to: outputPath)

            let persistent = result.discrepancies.filter { $0.kind == .persistent }
            let singleRun = result.discrepancies.filter { $0.kind == .singleRun }
            if !singleRun.isEmpty {
                writeStderr("warning: \(singleRun.count) single-run discrepancy(ies) detected:\n")
                for d in singleRun {
                    writeStderr("  - \(d.bundleIdentifier) [\(d.scenarioName)]: registry expects \(d.registryExpectation), observed \(d.observedInteractionMethod) (last: \(d.lastObservedAt))\n")
                }
            }
            if !persistent.isEmpty {
                writeStderr("error: \(persistent.count) persistent discrepancy(ies) — registry expectations disagree with observed reality for 3 consecutive runs:\n")
                for d in persistent {
                    writeStderr("  - \(d.bundleIdentifier) [\(d.scenarioName)]: registry expects \(d.registryExpectation), observed \(d.observedInteractionMethod) (last: \(d.lastObservedAt))\n")
                }
                writeStderr("Resolution: update the registry (Sources/MacOSControlLib/Router/Defaults/default-app-capabilities.json) or fix the underlying interaction-layer regression.\n")
                return ExitCode.persistentDiscrepancy
            }
            return ExitCode.ok
        } catch {
            writeStderr("error: \(error)\n")
            return ExitCode.dataError
        }
    }

    private static func writeStderr(_ s: String) {
        FileHandle.standardError.write(Data(s.utf8))
    }

    // MARK: - Internals

    private static func loadRegistry(from url: URL) throws -> InMemoryCapabilityRegistry {
        let data = try Data(contentsOf: url)
        // Decode the shipped registry's JSON shape (forward-compatible: unknown
        // keys are ignored by the decoder, matching `RawRegistryFile`).
        struct Raw: Decodable {
            let schemaVersion: Int
            let entries: [RawEntry]
            enum CodingKeys: String, CodingKey {
                case schemaVersion = "schema_version"
                case entries
            }
        }
        struct RawEntry: Decodable {
            let bundleId: String
            let axSupported: Bool
            let applescriptSupported: Bool
            let hitTestSupported: Bool
            enum CodingKeys: String, CodingKey {
                case bundleId = "bundle_id"
                case axSupported = "ax_supported"
                case applescriptSupported = "applescript_supported"
                case hitTestSupported = "hit_test_supported"
            }
        }
        let raw = try JSONDecoder().decode(Raw.self, from: data)
        let entries = raw.entries.map {
            CapabilityEntry(
                bundleId: $0.bundleId,
                axSupported: CapabilityFlag(bool: $0.axSupported),
                applescriptSupported: CapabilityFlag(bool: $0.applescriptSupported),
                hitTestSupported: CapabilityFlag(bool: $0.hitTestSupported),
                source: .defaults
            )
        }
        let modified = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? Date()
        return InMemoryCapabilityRegistry(
            entries: entries,
            schemaVersion: raw.schemaVersion,
            lastModified: modified
        )
    }

    private static func writeMarkdown(_ markdown: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try markdown.write(to: url, atomically: true, encoding: .utf8)
    }
}

/// Loaded-from-JSON registry view. Used only by the catalog CLI — the running
/// MCP server uses `AppCapabilityRegistry` which knows how to merge bundled
/// defaults with user overrides. The CLI is intentionally simpler: one file in,
/// one read-only view out.
final class InMemoryCapabilityRegistry: CapabilityRegistryReading, @unchecked Sendable {
    let allEntries: [CapabilityEntry]
    let schemaVersion: Int
    let lastModified: Date

    init(entries: [CapabilityEntry], schemaVersion: Int, lastModified: Date) {
        self.allEntries = entries
        self.schemaVersion = schemaVersion
        self.lastModified = lastModified
    }
}

