import Foundation

// STORY-019 — Per-Application Capability Registry
//
// Load-once, query-many data layer that tells the future `smart_interact`
// router (STORY-010) which interaction layers are worth attempting for a given
// application. Bundled defaults ship in `Router/Defaults/default-app-capabilities.json`;
// users may shadow individual entries via an override file (see `OverrideFileLoader`).
//
// Concurrency: defaults + overrides are read once during `load()` (called at
// server startup, before request handling) into immutable maps; subsequent
// lookups are O(1) and lock-free-after-load. An NSLock still guards the
// load/read boundary so a stray concurrent reader can never observe a torn map
// (mirrors `ErrorCodeRegistry`'s `@unchecked Sendable` + NSLock posture).

// MARK: - Domain types

/// Tri-state per-layer support. `.unknown` is returned for apps absent from the
/// registry; the router treats `.unknown` as "optimistically attempt the layer".
public enum CapabilityFlag: Equatable, Sendable {
    case yes
    case no
    case unknown

    init(bool: Bool) { self = bool ? .yes : .no }
}

/// Where a resolved capability came from. Surfaced so operators inspecting the
/// MCP Resource can see whether a value is a shipped default or a user override.
public enum CapabilitySource: String, Equatable, Sendable {
    case defaults
    case userOverride = "user_override"
    case unknown
}

/// A single registered application's capabilities.
public struct CapabilityEntry: Equatable, Sendable {
    public let bundleId: String
    public let axSupported: CapabilityFlag
    public let applescriptSupported: CapabilityFlag
    public let hitTestSupported: CapabilityFlag
    public let source: CapabilitySource

    public init(
        bundleId: String,
        axSupported: CapabilityFlag,
        applescriptSupported: CapabilityFlag,
        hitTestSupported: CapabilityFlag,
        source: CapabilitySource
    ) {
        self.bundleId = bundleId
        self.axSupported = axSupported
        self.applescriptSupported = applescriptSupported
        self.hitTestSupported = hitTestSupported
        self.source = source
    }
}

/// The always-non-nil result of a lookup. Unregistered apps resolve to all
/// `.unknown` with `source == .unknown`.
public struct CapabilitiesResult: Equatable, Sendable {
    public let axSupported: CapabilityFlag
    public let applescriptSupported: CapabilityFlag
    public let hitTestSupported: CapabilityFlag
    public let source: CapabilitySource

    public static let unknown = CapabilitiesResult(
        axSupported: .unknown,
        applescriptSupported: .unknown,
        hitTestSupported: .unknown,
        source: .unknown
    )

    init(entry: CapabilityEntry) {
        axSupported = entry.axSupported
        applescriptSupported = entry.applescriptSupported
        hitTestSupported = entry.hitTestSupported
        source = entry.source
    }

    public init(
        axSupported: CapabilityFlag,
        applescriptSupported: CapabilityFlag,
        hitTestSupported: CapabilityFlag,
        source: CapabilitySource
    ) {
        self.axSupported = axSupported
        self.applescriptSupported = applescriptSupported
        self.hitTestSupported = hitTestSupported
        self.source = source
    }
}

// MARK: - Codable wire format

/// Decoded directly from JSON. Swift's synthesized `init(from:)` ignores
/// unknown keys, so a future v2 file adding `drag_supported` / `_future_field`
/// decodes cleanly against this v1 shape — the forward-compat guarantee.
struct RawRegistryFile: Decodable {
    let schemaVersion: Int
    let entries: [RawCapabilityEntry]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case entries
    }
}

struct RawCapabilityEntry: Decodable {
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

    func entry(source: CapabilitySource) -> CapabilityEntry {
        CapabilityEntry(
            bundleId: bundleId,
            axSupported: CapabilityFlag(bool: axSupported),
            applescriptSupported: CapabilityFlag(bool: applescriptSupported),
            hitTestSupported: CapabilityFlag(bool: hitTestSupported),
            source: source
        )
    }
}

// MARK: - Injectable seams

/// Bundled defaults payload plus its file modification date (when knowable),
/// surfaced so the MCP Resource can report a `last_modified` timestamp.
public struct LoadedDefaults: Sendable {
    public let data: Data
    public let modifiedAt: Date?
    public init(data: Data, modifiedAt: Date? = nil) {
        self.data = data
        self.modifiedAt = modifiedAt
    }
}

/// Reads the package-bundled `default-app-capabilities.json`.
public protocol DefaultCapabilitiesLoading {
    func load() throws -> LoadedDefaults
}

/// A located override file plus its on-disk path (for error reporting) and
/// modification date (folded into the registry's `last_modified`).
public struct OverrideSource: Sendable {
    public let data: Data
    public let path: String
    public let modifiedAt: Date?
    public init(data: Data, path: String, modifiedAt: Date? = nil) {
        self.data = data
        self.path = path
        self.modifiedAt = modifiedAt
    }
}

/// Reads the optional user override file. Returns `nil` when no override file
/// exists (the common case — not an error). Throws only on a real read failure.
public protocol OverrideCapabilitiesLoading {
    func load() throws -> OverrideSource?
}

/// Logging seam for the one structured error this subsystem can emit. There is
/// no pre-existing `StructuredLogger` protocol in the codebase, so we keep this
/// narrow and injectable rather than inventing a global one.
public protocol CapabilityRegistryLogging {
    func logOverrideError(filePath: String, line: Int?, message: String)
}

/// Read-only view consumed by the MCP Resource adapter so it can be tested
/// against a fake registry.
public protocol CapabilityRegistryReading: AnyObject {
    var allEntries: [CapabilityEntry] { get }
    var schemaVersion: Int { get }
    /// When the registry's effective data was last modified — the most recent
    /// file mtime among the loaded sources, falling back to the load time.
    var lastModified: Date { get }
}

// MARK: - Registry

public final class AppCapabilityRegistry: @unchecked Sendable, CapabilityRegistryReading {

    public static let overrideErrorCode = "invalid_capability_registry_override"

    private let defaultsLoader: DefaultCapabilitiesLoading
    private let overridesLoader: OverrideCapabilitiesLoading
    private let logger: CapabilityRegistryLogging

    private let lock = NSLock()
    private var defaultsByID: [String: CapabilityEntry] = [:]
    private var effectiveByID: [String: CapabilityEntry] = [:]
    private var orderedBundleIDs: [String] = []
    private var loadedSchemaVersion: Int = 1
    private var loadedLastModified: Date = .distantPast

    public init(
        defaultsLoader: DefaultCapabilitiesLoading,
        overridesLoader: OverrideCapabilitiesLoading,
        logger: CapabilityRegistryLogging = DefaultCapabilityRegistryLogger()
    ) {
        self.defaultsLoader = defaultsLoader
        self.overridesLoader = overridesLoader
        self.logger = logger
    }

    /// Production registry wired to the bundled defaults + the user override file.
    public static func standardRegistry() -> AppCapabilityRegistry {
        AppCapabilityRegistry(
            defaultsLoader: BundleDefaultCapabilitiesLoader(),
            overridesLoader: OverrideFileLoader()
        )
    }

    /// Defaults are required infrastructure: a missing or malformed bundled
    /// file `throws` (the server then refuses to start). Override loading is
    /// fail-soft: any failure is logged as a structured error and the server
    /// continues with defaults only.
    public func load() throws {
        let loadedDefaults = try defaultsLoader.load()
        let defaultsFile: RawRegistryFile
        do {
            defaultsFile = try JSONDecoder().decode(RawRegistryFile.self, from: loadedDefaults.data)
        } catch {
            throw DefaultsDecodeError(underlying: error)
        }

        var defaults: [String: CapabilityEntry] = [:]
        var order: [String] = []
        for raw in defaultsFile.entries where defaults[raw.bundleId] == nil {
            defaults[raw.bundleId] = raw.entry(source: .defaults)
            order.append(raw.bundleId)
        }

        var effective = defaults
        var modificationDates: [Date] = [loadedDefaults.modifiedAt].compactMap { $0 }

        if let override = loadOverridesFailSoft() {
            for raw in override.file.entries {
                effective[raw.bundleId] = raw.entry(source: .userOverride)
                if defaults[raw.bundleId] == nil { order.append(raw.bundleId) }
            }
            if let overrideModified = override.modifiedAt { modificationDates.append(overrideModified) }
        }

        // Most recent source mtime; absent any (fakes, bundle without a stat),
        // fall back to load time — meaningful because there is no hot-reload.
        let lastModified = modificationDates.max() ?? Date()

        lock.lock()
        defaultsByID = defaults
        effectiveByID = effective
        orderedBundleIDs = order
        loadedSchemaVersion = defaultsFile.schemaVersion
        loadedLastModified = lastModified
        lock.unlock()
    }

    /// Always returns a value. Unregistered bundle ids resolve to `.unknown`.
    public func capabilities(for bundleId: String) -> CapabilitiesResult {
        lock.lock()
        let entry = effectiveByID[bundleId]
        lock.unlock()
        guard let entry else { return .unknown }
        return CapabilitiesResult(entry: entry)
    }

    /// The shipped default for a bundle id, even when shadowed by an override.
    public func defaultEntry(for bundleId: String) -> CapabilityEntry? {
        lock.lock(); defer { lock.unlock() }
        return defaultsByID[bundleId]
    }

    public var allEntries: [CapabilityEntry] {
        lock.lock(); defer { lock.unlock() }
        return orderedBundleIDs.compactMap { effectiveByID[$0] }
    }

    public var schemaVersion: Int {
        lock.lock(); defer { lock.unlock() }
        return loadedSchemaVersion
    }

    public var lastModified: Date {
        lock.lock(); defer { lock.unlock() }
        return loadedLastModified
    }

    // MARK: - Override fail-soft

    private func loadOverridesFailSoft() -> (file: RawRegistryFile, modifiedAt: Date?)? {
        let source: OverrideSource?
        do {
            source = try overridesLoader.load()
        } catch {
            logger.logOverrideError(
                filePath: "<unreadable>",
                line: nil,
                message: "Failed to read user override file: \(error)"
            )
            return nil
        }
        guard let source else { return nil }
        do {
            let file = try JSONDecoder().decode(RawRegistryFile.self, from: source.data)
            return (file, source.modifiedAt)
        } catch {
            logger.logOverrideError(
                filePath: source.path,
                line: jsonErrorLine(error),
                message: "Skipping malformed override file: \(error)"
            )
            return nil
        }
    }

    /// `JSONDecoder` does not expose line numbers. Best-effort: `JSONSerialization`
    /// records a byte offset in `NSJSONSerializationErrorIndex`, nested as the
    /// underlying error of a `DecodingError.dataCorrupted`. Surface it when
    /// available (the story asks for line "when available").
    private func jsonErrorLine(_ error: Error) -> Int? {
        if let index = (error as NSError).userInfo["NSJSONSerializationErrorIndex"] as? Int {
            return index
        }
        if case let DecodingError.dataCorrupted(context) = error,
           let underlying = context.underlyingError as NSError?,
           let index = underlying.userInfo["NSJSONSerializationErrorIndex"] as? Int {
            return index
        }
        return nil
    }

    public struct DefaultsDecodeError: Error, CustomStringConvertible {
        public let underlying: Error
        public var description: String {
            "default-app-capabilities.json failed to decode: \(underlying)"
        }
    }
}

// MARK: - Real loader implementations

public struct BundleDefaultCapabilitiesLoader: DefaultCapabilitiesLoading {
    public init() {}

    public enum LoadError: Error, CustomStringConvertible {
        case missingBundledResource
        public var description: String {
            "Bundled default-app-capabilities.json is missing from the package resources"
        }
    }

    public func load() throws -> LoadedDefaults {
        guard let url = Bundle.module.url(
            forResource: "default-app-capabilities",
            withExtension: "json",
            subdirectory: "Defaults"
        ) else {
            throw LoadError.missingBundledResource
        }
        let data = try Data(contentsOf: url)
        let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        return LoadedDefaults(data: data, modifiedAt: modifiedAt)
    }
}

public struct OverrideFileLoader: OverrideCapabilitiesLoading {
    public static let envVar = "MCP_MACOS_CONTROL_OVERRIDES_PATH"

    private let environment: [String: String]
    private let fileManager: FileManager

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) {
        self.environment = environment
        self.fileManager = fileManager
    }

    public func load() throws -> OverrideSource? {
        guard let path = resolvedPath() else { return nil }
        guard fileManager.fileExists(atPath: path) else { return nil }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let modifiedAt = (try? fileManager.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        return OverrideSource(data: data, path: path, modifiedAt: modifiedAt)
    }

    private func resolvedPath() -> String? {
        if let override = environment[Self.envVar], !override.isEmpty {
            return (override as NSString).expandingTildeInPath
        }
        guard let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return appSupport
            .appendingPathComponent("mcp-macos-control")
            .appendingPathComponent("app-overrides.json")
            .path
    }
}

/// Default logger: emits the same `{ok:false, error:{...}}` envelope shape that
/// `Server.swift` uses for resource/prompt errors, to stderr, plus a warn line.
public struct DefaultCapabilityRegistryLogger: CapabilityRegistryLogging {
    public init() {}

    public func logOverrideError(filePath: String, line: Int?, message: String) {
        var details: [String: Any] = ["file_path": filePath]
        if let line { details["line"] = line }
        let envelope: [String: Any] = [
            "ok": false,
            "error": [
                "code": AppCapabilityRegistry.overrideErrorCode,
                "message": message,
                "details": details
            ]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            FileHandle.standardError.write(Data((text + "\n").utf8))
        }
        MCPLogger.warn("\(AppCapabilityRegistry.overrideErrorCode): \(message) (file=\(filePath))")
    }
}
