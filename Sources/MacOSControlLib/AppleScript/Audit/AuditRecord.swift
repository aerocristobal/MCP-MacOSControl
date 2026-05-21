// STORY-024 — Audit Log Integrity, Retention, and Off-Host Shipping
//
// `AuditRecord` is the 13-field record that lands on disk (JSONL),
// gets hash-chained, and is shipped to a remote sink. Designed so the
// *immutable forensic core* is hash-stable while the *delivery
// annotations* (delivery_status, remote_ack_timestamp) may be updated
// after write without breaking the chain — see canonicalJSONForHash().
//
// Why split core vs envelope? Acks happen asynchronously; if we put
// delivery_status in the hashed payload, the recorder would have to
// rewrite the record (violating append-only) every time an ack arrived.
// Instead, acks are appended to a sibling ack-ledger file (see
// AuditStorage). The on-disk record line is written ONCE and never
// rewritten. The merged view reconciles the two streams when read.

import Foundation
import CryptoKit

/// Schema version stamped on every record. Bump when the schema's
/// canonical JSON shape changes (so verifiers can pick the right
/// hashing rule for older records).
public let auditSchemaVersion: Int = 1

public enum AuditEventType: String, Codable, Equatable, Sendable, CaseIterable {
    case applescriptExecute = "applescript_execute"
    case menuClick = "menu_click"
    case menuAlternativesLookup = "menu_alternatives_lookup"
    case administrativeForceRotateUnacked = "administrative_force_rotate_unacked"
    case chainVerificationFailure = "chain_verification_failure"
}

public enum AuditFilterDisposition: String, Codable, Equatable, Sendable, CaseIterable {
    case allowed
    case rejectedSecurity = "rejected_security"
    case rejectedPermission = "rejected_permission"
    case notApplicable = "not_applicable"
}

public enum AuditExecutionOutcome: String, Codable, Equatable, Sendable, CaseIterable {
    case success
    case scriptError = "script_error"
    case timeout
    case ioError = "io_error"
    case notExecuted = "not_executed"
    case administrative
    case cancelled
}

public enum AuditDeliveryStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case pending
    case acknowledged
    case failed
}

/// The 13 mandatory fields per STORY-024 §2 plus a few optional details
/// (rejection_reason, denied_app, script_error_code, duration_ms) that
/// fall out of the call sites in RunAppleScriptTool and MenuClickBackend.
/// Optional details are part of the immutable core but not part of the
/// "mandatory" outline — verifier just reads whatever's there.
public struct AuditRecord: Codable, Equatable, Sendable {

    public let recordId: UUID
    public let timestampIso8601: String
    public let eventType: AuditEventType
    public let scriptSha256: String
    public let targetAppsExtracted: [String]
    public let filterDisposition: AuditFilterDisposition
    public let executionOutcome: AuditExecutionOutcome
    public let prevHash: String
    public let recordHash: String
    public let deliveryStatus: AuditDeliveryStatus
    public let remoteAckTimestamp: String?
    public let hostIdentifier: String
    public let serverVersion: String

    public let auditSchemaVersion: Int

    public let durationMs: Int
    public let rejectionReason: String?
    public let deniedApp: String?
    public let scriptErrorCode: Int?

    public init(
        recordId: UUID,
        timestampIso8601: String,
        eventType: AuditEventType,
        scriptSha256: String,
        targetAppsExtracted: [String],
        filterDisposition: AuditFilterDisposition,
        executionOutcome: AuditExecutionOutcome,
        prevHash: String,
        recordHash: String,
        deliveryStatus: AuditDeliveryStatus,
        remoteAckTimestamp: String?,
        hostIdentifier: String,
        serverVersion: String,
        auditSchemaVersion: Int = MacOSControlLib_auditSchemaVersion(),
        durationMs: Int = 0,
        rejectionReason: String? = nil,
        deniedApp: String? = nil,
        scriptErrorCode: Int? = nil
    ) {
        self.recordId = recordId
        self.timestampIso8601 = timestampIso8601
        self.eventType = eventType
        self.scriptSha256 = scriptSha256
        self.targetAppsExtracted = targetAppsExtracted
        self.filterDisposition = filterDisposition
        self.executionOutcome = executionOutcome
        self.prevHash = prevHash
        self.recordHash = recordHash
        self.deliveryStatus = deliveryStatus
        self.remoteAckTimestamp = remoteAckTimestamp
        self.hostIdentifier = hostIdentifier
        self.serverVersion = serverVersion
        self.auditSchemaVersion = auditSchemaVersion
        self.durationMs = durationMs
        self.rejectionReason = rejectionReason
        self.deniedApp = deniedApp
        self.scriptErrorCode = scriptErrorCode
    }

    enum CodingKeys: String, CodingKey {
        case recordId = "record_id"
        case timestampIso8601 = "timestamp_iso8601"
        case eventType = "event_type"
        case scriptSha256 = "script_sha256"
        case targetAppsExtracted = "target_apps_extracted"
        case filterDisposition = "filter_disposition"
        case executionOutcome = "execution_outcome"
        case prevHash = "prev_hash"
        case recordHash = "record_hash"
        case deliveryStatus = "delivery_status"
        case remoteAckTimestamp = "remote_ack_timestamp"
        case hostIdentifier = "host_identifier"
        case serverVersion = "server_version"
        case auditSchemaVersion = "audit_schema_version"
        case durationMs = "duration_ms"
        case rejectionReason = "rejection_reason"
        case deniedApp = "denied_app"
        case scriptErrorCode = "script_error_code"
    }

    /// Custom encode so the mandatory `remote_ack_timestamp` field is
    /// always emitted (as JSON null when not yet acknowledged), per the
    /// BDD outline "field: nullable_string". The default Codable
    /// behavior drops nil optionals — which would make the schema look
    /// like it's missing a mandatory field.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(recordId, forKey: .recordId)
        try c.encode(timestampIso8601, forKey: .timestampIso8601)
        try c.encode(eventType, forKey: .eventType)
        try c.encode(scriptSha256, forKey: .scriptSha256)
        try c.encode(targetAppsExtracted, forKey: .targetAppsExtracted)
        try c.encode(filterDisposition, forKey: .filterDisposition)
        try c.encode(executionOutcome, forKey: .executionOutcome)
        try c.encode(prevHash, forKey: .prevHash)
        try c.encode(recordHash, forKey: .recordHash)
        try c.encode(deliveryStatus, forKey: .deliveryStatus)
        // Mandatory field — emit JSON null when unset.
        if let v = remoteAckTimestamp {
            try c.encode(v, forKey: .remoteAckTimestamp)
        } else {
            try c.encodeNil(forKey: .remoteAckTimestamp)
        }
        try c.encode(hostIdentifier, forKey: .hostIdentifier)
        try c.encode(serverVersion, forKey: .serverVersion)
        try c.encode(auditSchemaVersion, forKey: .auditSchemaVersion)
        try c.encode(durationMs, forKey: .durationMs)
        // Optional details — only emit when present.
        try c.encodeIfPresent(rejectionReason, forKey: .rejectionReason)
        try c.encodeIfPresent(deniedApp, forKey: .deniedApp)
        try c.encodeIfPresent(scriptErrorCode, forKey: .scriptErrorCode)
    }

    /// Canonical JSON over the immutable forensic core, excluding
    /// `record_hash` itself and the mutable delivery annotations
    /// (`delivery_status`, `remote_ack_timestamp`). The bytes returned
    /// here are what `record_hash` SHA-256-hashes. Keys are sorted to
    /// guarantee a stable hash across implementations.
    public func canonicalJSONForHash() throws -> Data {
        var dict: [String: Any] = [
            "record_id": recordId.uuidString,
            "timestamp_iso8601": timestampIso8601,
            "event_type": eventType.rawValue,
            "script_sha256": scriptSha256,
            "target_apps_extracted": targetAppsExtracted,
            "filter_disposition": filterDisposition.rawValue,
            "execution_outcome": executionOutcome.rawValue,
            "prev_hash": prevHash,
            "host_identifier": hostIdentifier,
            "server_version": serverVersion,
            "audit_schema_version": auditSchemaVersion,
            "duration_ms": durationMs
        ]
        if let reason = rejectionReason { dict["rejection_reason"] = reason }
        if let app = deniedApp { dict["denied_app"] = app }
        if let code = scriptErrorCode { dict["script_error_code"] = code }

        return try JSONSerialization.data(
            withJSONObject: dict,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }

    /// SHA-256 hex digest of `canonicalJSONForHash()`.
    public func computeRecordHash() throws -> String {
        let bytes = try canonicalJSONForHash()
        let digest = SHA256.hash(data: bytes)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Build a copy of `self` with `deliveryStatus`/`remoteAckTimestamp`
    /// replaced — used when an ack arrives. Does NOT change record_hash:
    /// the canonical JSON excludes these fields by design.
    public func annotated(
        deliveryStatus: AuditDeliveryStatus,
        remoteAckTimestamp: String?
    ) -> AuditRecord {
        AuditRecord(
            recordId: recordId,
            timestampIso8601: timestampIso8601,
            eventType: eventType,
            scriptSha256: scriptSha256,
            targetAppsExtracted: targetAppsExtracted,
            filterDisposition: filterDisposition,
            executionOutcome: executionOutcome,
            prevHash: prevHash,
            recordHash: recordHash,
            deliveryStatus: deliveryStatus,
            remoteAckTimestamp: remoteAckTimestamp,
            hostIdentifier: hostIdentifier,
            serverVersion: serverVersion,
            auditSchemaVersion: auditSchemaVersion,
            durationMs: durationMs,
            rejectionReason: rejectionReason,
            deniedApp: deniedApp,
            scriptErrorCode: scriptErrorCode
        )
    }
}

/// A draft is the call-site payload — everything the caller knows about
/// the event. The recorder fills in record_id, prev_hash, record_hash,
/// delivery_status (.pending), and the host/version fields.
public struct AuditRecordDraft: Equatable, Sendable {
    public var timestamp: Date
    public var eventType: AuditEventType
    public var scriptSha256: String
    public var targetApps: [String]
    public var filterDisposition: AuditFilterDisposition
    public var executionOutcome: AuditExecutionOutcome
    public var durationMs: Int
    public var rejectionReason: String?
    public var deniedApp: String?
    public var scriptErrorCode: Int?

    public init(
        timestamp: Date = Date(),
        eventType: AuditEventType,
        scriptSha256: String,
        targetApps: [String] = [],
        filterDisposition: AuditFilterDisposition,
        executionOutcome: AuditExecutionOutcome,
        durationMs: Int = 0,
        rejectionReason: String? = nil,
        deniedApp: String? = nil,
        scriptErrorCode: Int? = nil
    ) {
        self.timestamp = timestamp
        self.eventType = eventType
        self.scriptSha256 = scriptSha256
        self.targetApps = targetApps
        self.filterDisposition = filterDisposition
        self.executionOutcome = executionOutcome
        self.durationMs = durationMs
        self.rejectionReason = rejectionReason
        self.deniedApp = deniedApp
        self.scriptErrorCode = scriptErrorCode
    }
}

/// ISO8601 with milliseconds + UTC. Used everywhere we serialize a Date
/// into an audit record — making the canonical form parser-stable.
public enum AuditTimestamp {
    public static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    public static func format(_ date: Date) -> String {
        formatter.string(from: date)
    }

    public static func parse(_ string: String) -> Date? {
        formatter.date(from: string)
    }
}

/// Allows the default-arg `auditSchemaVersion:` parameter to refer to
/// the file-level constant without a name collision with the struct
/// stored property.
public func MacOSControlLib_auditSchemaVersion() -> Int { auditSchemaVersion }

/// Raised when a code path tries to write a record whose record_id is
/// already in storage — append-only enforcement per BDD §2.
public struct AuditLogImmutabilityViolation: Error, Equatable, CustomStringConvertible {
    public let recordId: UUID
    public init(recordId: UUID) { self.recordId = recordId }
    public var description: String {
        "audit_log_immutability_violation: record_id \(recordId.uuidString) already exists"
    }
}

/// Raised by AuditConfig.validate() when env vars are internally inconsistent.
public struct AuditConfigInvalid: Error, Equatable, CustomStringConvertible {
    public let missingVariable: String?
    public let reason: String
    public init(missingVariable: String? = nil, reason: String) {
        self.missingVariable = missingVariable
        self.reason = reason
    }
    public var description: String {
        if let v = missingVariable {
            return "audit_config_invalid: \(reason) (missing variable: \(v))"
        }
        return "audit_config_invalid: \(reason)"
    }
}

/// Raised when chain verification finds a break. Surfaced via OSLog at
/// server start and via the remote sink as an auditable event.
public struct AuditChainVerificationFailure: Error, Equatable, CustomStringConvertible {
    public let firstBreakAt: UUID?
    public let totalChecked: Int
    public let summary: String
    public init(firstBreakAt: UUID?, totalChecked: Int, summary: String) {
        self.firstBreakAt = firstBreakAt
        self.totalChecked = totalChecked
        self.summary = summary
    }
    public var description: String {
        "audit_chain_verification_failed: \(summary) (firstBreakAt=\(firstBreakAt?.uuidString ?? "<nil>"), totalChecked=\(totalChecked))"
    }
}
