import Foundation

// STORY-019 — MCP Resource adapter for the per-app capability registry.
//
// Wired into the existing STORY-013 resource machinery (MCPResourceCatalog +
// the ReadResource switch in Server.swift) rather than a bespoke protocol —
// STORY-013 ships no formal resource protocol. Shape mirrors
// `ActiveApplicationResource`: a `read() -> [String: Any]` the server
// serializes with JSONSerialization.

public final class CapabilityRegistryResource {

    private let registry: CapabilityRegistryReading

    public init(registry: CapabilityRegistryReading) {
        self.registry = registry
    }

    /// The complete registry document: schema_version + every effective entry
    /// with its resolution source.
    public func read() -> [String: Any] {
        let entries: [[String: Any]] = registry.allEntries.map { entry in
            [
                "bundle_id": entry.bundleId,
                "ax_supported": flagJSON(entry.axSupported),
                "applescript_supported": flagJSON(entry.applescriptSupported),
                "hit_test_supported": flagJSON(entry.hitTestSupported),
                "source": entry.source.rawValue
            ]
        }
        return [
            "schema_version": registry.schemaVersion,
            "last_modified": Self.iso8601.string(from: registry.lastModified),
            "entries": entries
        ]
    }

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Registry entries are always concrete yes/no; `.unknown` is only ever a
    /// lookup result, never a stored entry. Map defensively anyway.
    private func flagJSON(_ flag: CapabilityFlag) -> Any {
        switch flag {
        case .yes: return true
        case .no: return false
        case .unknown: return NSNull()
        }
    }
}
