// STORY-024 — Off-host shipping.
//
// Three sinks share a single protocol so the recorder's hot path is
// identical regardless of destination. All sinks return the
// acknowledgment timestamp on success and throw on timeout/failure;
// the recorder annotates the local record with the timestamp via
// AuditStorage.appendAck.
//
// Default: OSLog (subsystem com.mcp.macos-control.audit) — built into
// macOS, requires no external service, visible in Console.app, and
// collected by enterprise MDM tooling on macOS.
//
// Opt-in: HTTP (managed log collectors / SIEM) and syslog (legacy
// infrastructure). Both configured via env vars per AuditConfig.

import Foundation
import os.log

public protocol AuditRemoteSink: AnyObject, Sendable {
    /// Ship a record. Returns the ack timestamp on success. Throws on
    /// timeout or transport failure — the caller (AuditRecorder)
    /// records this as delivery_status=pending and retries.
    func ship(_ record: AuditRecord, timeoutMs: Int) async throws -> Date
}

public struct AuditRemoteSinkError: Error, Equatable, CustomStringConvertible {
    public let kind: Kind
    public enum Kind: Equatable {
        case timeout
        case transport(String)
        case http(statusCode: Int)
    }
    public init(_ kind: Kind) { self.kind = kind }
    public var description: String {
        switch kind {
        case .timeout: return "audit_remote_sink_timeout"
        case .transport(let detail): return "audit_remote_sink_transport: \(detail)"
        case .http(let status): return "audit_remote_sink_http_status: \(status)"
        }
    }
}

/// OSLog default sink. The os_log family is the macOS-native audit
/// pipeline — records land in the unified log and are visible via
/// `log show --predicate 'subsystem == "com.mcp.macos-control.audit"'`.
/// Operators with MDM tooling that scrapes the unified log get
/// shipping for free.
public final class OSLogAuditSink: AuditRemoteSink, @unchecked Sendable {
    public static let subsystem = "com.mcp.macos-control.audit"
    public static let category = "audit"

    private let logger: os.Logger

    public init() {
        self.logger = os.Logger(subsystem: Self.subsystem, category: Self.category)
    }

    public func ship(_ record: AuditRecord, timeoutMs: Int) async throws -> Date {
        // OSLog writes are synchronous against the in-process log
        // shim; an "ack" is "the call returned." There is no
        // network round-trip to time out on, so the timeout is
        // effectively unused for this sink. We still take the
        // ack timestamp from after the write.
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try enc.encode(record)
        let line = String(data: data, encoding: .utf8) ?? "{}"
        logger.log(level: .info, "\(line, privacy: .public)")
        return Date()
    }
}

/// HTTP sink. POSTs the canonical JSON to the configured URL and
/// considers a 2xx response an ack. The URLSession timeout is set
/// from `timeoutMs`. Body is the same JSON encoding used on disk —
/// so the SIEM operator's parser code looks identical regardless of
/// transport.
public final class HTTPAuditSink: AuditRemoteSink, @unchecked Sendable {
    private let url: URL
    private let session: URLSession

    public init(url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    public func ship(_ record: AuditRecord, timeoutMs: Int) async throws -> Date {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let body = try enc.encode(record)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("mcp-macos-control-audit/1", forHTTPHeaderField: "User-Agent")
        request.httpBody = body
        request.timeoutInterval = TimeInterval(timeoutMs) / 1000.0

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AuditRemoteSinkError(.transport("not an HTTPURLResponse"))
            }
            guard (200...299).contains(http.statusCode) else {
                throw AuditRemoteSinkError(.http(statusCode: http.statusCode))
            }
            return Date()
        } catch let e as AuditRemoteSinkError {
            throw e
        } catch let e as URLError where e.code == .timedOut {
            throw AuditRemoteSinkError(.timeout)
        } catch {
            throw AuditRemoteSinkError(.transport(String(describing: error)))
        }
    }
}

/// Syslog sink. Writes via os_log with the "auth" category convention
/// that macOS log-collection tools use for security-relevant events.
/// Differs from OSLogAuditSink only in category — kept as a separate
/// sink so the env-var contract maps 1:1 to user-visible categories
/// in `log show`.
public final class SyslogAuditSink: AuditRemoteSink, @unchecked Sendable {
    public static let subsystem = OSLogAuditSink.subsystem
    public static let category = "syslog"

    private let logger: os.Logger

    public init() {
        self.logger = os.Logger(subsystem: Self.subsystem, category: Self.category)
    }

    public func ship(_ record: AuditRecord, timeoutMs: Int) async throws -> Date {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try enc.encode(record)
        let line = String(data: data, encoding: .utf8) ?? "{}"
        logger.log(level: .info, "\(line, privacy: .public)")
        return Date()
    }
}

/// Factory for the configured sink. Reads AuditConfig.remoteSinkKind
/// and constructs the matching implementation.
public enum AuditRemoteSinkFactory {
    public static func make(config: AuditConfig) -> AuditRemoteSink {
        switch config.remoteSinkKind {
        case .oslog: return OSLogAuditSink()
        case .http:
            // Validated by AuditConfig.validate() — URL is non-nil at this point.
            return HTTPAuditSink(url: config.remoteSinkURL!)
        case .syslog: return SyslogAuditSink()
        }
    }
}
