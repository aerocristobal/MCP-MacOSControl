// STORY-024 — Per-install identity for the genesis hash.
//
// The genesis hash is the chain's root. It must be deterministic
// per-install so a verifier can recompute it offline, but unique enough
// across hosts/installs that an attacker who tampers with a chain can't
// simply swap in a chain from another install. We bind it to:
//   * host_identifier: POSIX gethostname()
//   * install_uuid:   UUID v4 generated on first run, persisted to
//                     ~/Library/Application Support/com.mcp.macos-control/install_uuid
//
// Both inputs are overridable via env vars (MCP_MACOS_CONTROL_AUDIT_*)
// for tests and deterministic CI runs.

import Foundation
import CryptoKit
#if canImport(Darwin)
import Darwin
#endif

public struct AuditInstallIdentity: Equatable, Sendable {
    public let hostIdentifier: String
    public let installUuid: String

    public init(hostIdentifier: String, installUuid: String) {
        self.hostIdentifier = hostIdentifier
        self.installUuid = installUuid
    }

    /// SHA-256 of the deterministic genesis tuple. The format string is
    /// part of the spec (Q4 of STORY-024) and must never change without
    /// a schema-version bump and a migration story.
    public var genesisHashHex: String {
        let input = "mcp-macos-control-audit-genesis|\(hostIdentifier)|\(installUuid)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

public enum AuditInstallIdentityResolver {

    public static let defaultInstallUuidSubpath = "com.mcp.macos-control/install_uuid"

    /// Resolve once at startup. Reads env-var overrides first, then
    /// hostname()/install-uuid file; creates the install_uuid file if
    /// absent. Initializing the file is best-effort — a missing file is
    /// preferable to a fatal startup error, and a random in-memory UUID
    /// gets generated as a fallback so the chain still works (though it
    /// won't survive a restart).
    public static func resolve(
        config: AuditConfig,
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) -> AuditInstallIdentity {
        let host = config.hostIdentifierOverride ?? Self.resolveHostname()
        let installUuid = config.installUuidOverride ?? Self.resolveInstallUuid(
            homeDirectoryURL: homeDirectoryURL,
            fileManager: fileManager
        )
        return AuditInstallIdentity(hostIdentifier: host, installUuid: installUuid)
    }

    private static func resolveHostname() -> String {
        #if canImport(Darwin)
        var buffer = [CChar](repeating: 0, count: 256)
        if gethostname(&buffer, buffer.count) == 0 {
            let s = String(cString: buffer)
            if !s.isEmpty { return s }
        }
        #endif
        return ProcessInfo.processInfo.hostName.isEmpty
            ? "unknown-host"
            : ProcessInfo.processInfo.hostName
    }

    private static func resolveInstallUuid(
        homeDirectoryURL: URL,
        fileManager: FileManager
    ) -> String {
        let appSupport = homeDirectoryURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(defaultInstallUuidSubpath, isDirectory: false)

        if let data = try? Data(contentsOf: appSupport),
           let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !s.isEmpty,
           UUID(uuidString: s) != nil {
            return s
        }

        // Generate, persist (best-effort), and return.
        let uuid = UUID().uuidString
        let parent = appSupport.deletingLastPathComponent()
        try? fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        try? Data(uuid.utf8).write(to: appSupport, options: .atomic)
        return uuid
    }
}
