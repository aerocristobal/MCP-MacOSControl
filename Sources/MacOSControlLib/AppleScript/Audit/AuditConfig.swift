// STORY-024 — Audit configuration loaded from environment variables.
//
// All audit-related env vars are gathered here. validate() throws
// AuditConfigInvalid on internal inconsistency — server fails to start
// per BDD scenario "Server refuses to start when audit config is
// internally inconsistent".

import Foundation

public enum AuditRemoteSinkKind: String, Equatable, Sendable {
    case oslog
    case http
    case syslog
}

public struct AuditConfig: Equatable, Sendable {

    /// Directory holding `audit-YYYY-MM-DD.jsonl` (active) +
    /// `archive/` subdirectory. Defaults to
    /// `~/Library/Logs/com.mcp.macos-control/audit/`.
    public let logDirectory: URL

    /// Retention window in days. Records older than this AND with
    /// delivery_status=acknowledged are swept to archive.
    public let retentionDays: Int

    /// Remote sink to ship records to. OSLog is the default.
    public let remoteSinkKind: AuditRemoteSinkKind

    /// Required when remoteSinkKind == .http.
    public let remoteSinkURL: URL?

    /// Per-record ack timeout in milliseconds. Records that don't ack
    /// inside this window stay `delivery_status: pending` and the
    /// retry loop will try again later.
    public let ackTimeoutMs: Int

    /// Overrides for testing — bypass gethostname()/install-uuid file.
    public let hostIdentifierOverride: String?
    public let installUuidOverride: String?

    /// When true, the ForceRotateUnackedTool MCP tool is exposed.
    /// Default false — operator must opt in explicitly per Q3 of the story.
    public let adminToolsEnabled: Bool

    public init(
        logDirectory: URL,
        retentionDays: Int,
        remoteSinkKind: AuditRemoteSinkKind,
        remoteSinkURL: URL?,
        ackTimeoutMs: Int,
        hostIdentifierOverride: String?,
        installUuidOverride: String?,
        adminToolsEnabled: Bool
    ) {
        self.logDirectory = logDirectory
        self.retentionDays = retentionDays
        self.remoteSinkKind = remoteSinkKind
        self.remoteSinkURL = remoteSinkURL
        self.ackTimeoutMs = ackTimeoutMs
        self.hostIdentifierOverride = hostIdentifierOverride
        self.installUuidOverride = installUuidOverride
        self.adminToolsEnabled = adminToolsEnabled
    }

    public static let defaultLogSubpath = "com.mcp.macos-control/audit"
    public static let defaultRetentionDays = 365
    public static let defaultAckTimeoutMs = 5_000

    /// Load from environment. Does not throw on invalid values — sets
    /// defaults — but `validate()` enforces internal consistency and
    /// must be called before the config is used in production.
    public static func load(
        env: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> AuditConfig {
        let logDir: URL = {
            if let p = env["MCP_MACOS_CONTROL_AUDIT_DIR"], !p.isEmpty {
                return URL(fileURLWithPath: (p as NSString).expandingTildeInPath, isDirectory: true)
            }
            return homeDirectoryURL
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Logs", isDirectory: true)
                .appendingPathComponent(defaultLogSubpath, isDirectory: true)
        }()

        let retention: Int = {
            guard let s = env["MCP_MACOS_CONTROL_AUDIT_RETENTION_DAYS"], let n = Int(s) else {
                return defaultRetentionDays
            }
            return n
        }()

        let kind: AuditRemoteSinkKind = {
            guard let s = env["MCP_MACOS_CONTROL_AUDIT_REMOTE"]?.lowercased(),
                  let k = AuditRemoteSinkKind(rawValue: s) else { return .oslog }
            return k
        }()

        let url: URL? = {
            guard let s = env["MCP_MACOS_CONTROL_AUDIT_REMOTE_URL"], !s.isEmpty else { return nil }
            return URL(string: s)
        }()

        let ackMs: Int = {
            guard let s = env["MCP_MACOS_CONTROL_AUDIT_ACK_TIMEOUT_MS"], let n = Int(s) else {
                return defaultAckTimeoutMs
            }
            return n
        }()

        let admin = (env["MCP_MACOS_CONTROL_AUDIT_ADMIN_ENABLED"]?.lowercased() == "true")

        return AuditConfig(
            logDirectory: logDir,
            retentionDays: retention,
            remoteSinkKind: kind,
            remoteSinkURL: url,
            ackTimeoutMs: ackMs,
            hostIdentifierOverride: env["MCP_MACOS_CONTROL_AUDIT_HOST_IDENTIFIER"],
            installUuidOverride: env["MCP_MACOS_CONTROL_AUDIT_INSTALL_UUID"],
            adminToolsEnabled: admin
        )
    }

    public func validate() throws {
        if remoteSinkKind == .http {
            guard let url = remoteSinkURL else {
                throw AuditConfigInvalid(
                    missingVariable: "MCP_MACOS_CONTROL_AUDIT_REMOTE_URL",
                    reason: "MCP_MACOS_CONTROL_AUDIT_REMOTE=http requires MCP_MACOS_CONTROL_AUDIT_REMOTE_URL"
                )
            }
            guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
                throw AuditConfigInvalid(
                    missingVariable: "MCP_MACOS_CONTROL_AUDIT_REMOTE_URL",
                    reason: "MCP_MACOS_CONTROL_AUDIT_REMOTE_URL must be an http(s) URL"
                )
            }
        }
        guard retentionDays >= 1 else {
            throw AuditConfigInvalid(
                missingVariable: "MCP_MACOS_CONTROL_AUDIT_RETENTION_DAYS",
                reason: "retention must be at least 1 day"
            )
        }
        guard ackTimeoutMs >= 100 else {
            throw AuditConfigInvalid(
                missingVariable: "MCP_MACOS_CONTROL_AUDIT_ACK_TIMEOUT_MS",
                reason: "ack timeout must be at least 100ms"
            )
        }
    }
}
