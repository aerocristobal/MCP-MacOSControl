// STORY-024 — Audit Log Integrity, Retention, and Off-Host Shipping
//
// This file went through a major rewrite in STORY-024. The shape:
//   * `AuditRecording` (protocol) — call-site seam (RunAppleScriptTool,
//     MenuClickBackend, ForceRotateUnackedTool all depend on this).
//     Previously named `AuditRecorder`.
//   * `AuditRecorder` (concrete class) — chained, persistent, off-host-
//     shipping recorder. Composes AuditStorage + AuditRemoteSink and
//     maintains the running chain head in memory.
//   * `InMemoryAuditRecorder` (concrete class) — lightweight conformer
//     for tests and dev. Still hash-chains records (so test assertions
//     about the chain still work) but writes everything to an
//     InMemoryAuditStorage and ships to a no-op sink.
//   * `ScriptHasher` — retained verbatim from STORY-006 (still used by
//     call sites to compute the script_sha256 *before* construction of
//     the draft).

import Foundation
import CryptoKit

// MARK: - SHA-256 of script source (used by call sites)

public enum ScriptHasher {
    public static func sha256Hex(_ source: String) -> String {
        let digest = SHA256.hash(data: Data(source.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Recorder seam

public protocol AuditRecording: AnyObject, Sendable {
    /// The current server's version string (e.g. "1.0.0"). Stamped on
    /// every record. Used by AuditRecorder when constructing records.
    var serverVersion: String { get }

    /// The per-install identity. Exposed so chain verifiers
    /// constructed alongside the recorder use the matching genesis.
    var identity: AuditInstallIdentity { get }

    /// Convenience: build a record from a draft, persist, schedule
    /// ship. Non-throwing — internal errors are logged but do not
    /// disturb the caller's hot path (an audit failure must not
    /// surface as a tool-call failure to the agent).
    @discardableResult
    func record(_ draft: AuditRecordDraft) -> AuditRecord

    /// Explicit append of a fully-built record. Throws
    /// `AuditLogImmutabilityViolation` if the record_id is already
    /// present. Used by tests and by paths that must know about
    /// duplicate insertion (force_rotate_unacked emits its own
    /// administrative record this way).
    @discardableResult
    func append(_ record: AuditRecord) throws -> AuditRecord
}

// MARK: - Production recorder

/// Default server version stamped on each record. The server's
/// Server.swift updates this at startup; default kept here so unit
/// tests don't need to wire it explicitly.
public let auditDefaultServerVersion = "1.0.0"

public final class AuditRecorder: AuditRecording, @unchecked Sendable {

    public let identity: AuditInstallIdentity
    public let serverVersion: String

    private let storage: AuditStorage
    private let remoteSink: AuditRemoteSink
    private let config: AuditConfig
    private let clock: Clock
    private let queue = DispatchQueue(label: "com.macoscontrol.audit.recorder", qos: .utility)

    /// Running chain head — last record_hash written or, when no
    /// record has been written yet, the per-install genesis hash.
    /// Mutated under `queue`.
    private var lastRecordHash: String

    public init(
        storage: AuditStorage,
        remoteSink: AuditRemoteSink,
        config: AuditConfig,
        identity: AuditInstallIdentity,
        clock: Clock = SystemClock(),
        serverVersion: String = auditDefaultServerVersion
    ) {
        self.storage = storage
        self.remoteSink = remoteSink
        self.config = config
        self.identity = identity
        self.clock = clock
        self.serverVersion = serverVersion

        // Initialize chain head from storage's tail (so a restart picks
        // up where the previous process left off). If storage is empty,
        // the head is the genesis.
        let existing = storage.allRecords()
        self.lastRecordHash = existing.last?.recordHash ?? identity.genesisHashHex
    }

    @discardableResult
    public func record(_ draft: AuditRecordDraft) -> AuditRecord {
        do {
            return try buildAndPersist(draft)
        } catch {
            MCPLogger.warn("AuditRecorder.record failed: \(error)")
            // Synthesize a record without persisting — caller still
            // gets a value. This keeps the call sites' contract
            // simple (always returns a record) but signals failure via
            // delivery_status=failed.
            return buildRecord(from: draft, persistFailed: true)
        }
    }

    @discardableResult
    public func append(_ record: AuditRecord) throws -> AuditRecord {
        try queue.sync {
            try storage.insert(record)
            lastRecordHash = record.recordHash
            scheduleShip(record)
            return record
        }
    }

    private func buildAndPersist(_ draft: AuditRecordDraft) throws -> AuditRecord {
        try queue.sync {
            let prev = lastRecordHash
            var record = makeRecord(from: draft, prevHash: prev, recordHash: "")
            let hash = try record.computeRecordHash()
            record = AuditRecord(
                recordId: record.recordId,
                timestampIso8601: record.timestampIso8601,
                eventType: record.eventType,
                scriptSha256: record.scriptSha256,
                targetAppsExtracted: record.targetAppsExtracted,
                filterDisposition: record.filterDisposition,
                executionOutcome: record.executionOutcome,
                prevHash: record.prevHash,
                recordHash: hash,
                deliveryStatus: .pending,
                remoteAckTimestamp: nil,
                hostIdentifier: record.hostIdentifier,
                serverVersion: record.serverVersion,
                auditSchemaVersion: record.auditSchemaVersion,
                durationMs: record.durationMs,
                rejectionReason: record.rejectionReason,
                deniedApp: record.deniedApp,
                scriptErrorCode: record.scriptErrorCode
            )

            try storage.insert(record)
            lastRecordHash = record.recordHash
            scheduleShip(record)
            return record
        }
    }

    private func makeRecord(
        from draft: AuditRecordDraft,
        prevHash: String,
        recordHash: String
    ) -> AuditRecord {
        AuditRecord(
            recordId: UUID(),
            timestampIso8601: AuditTimestamp.format(draft.timestamp),
            eventType: draft.eventType,
            scriptSha256: draft.scriptSha256,
            targetAppsExtracted: draft.targetApps,
            filterDisposition: draft.filterDisposition,
            executionOutcome: draft.executionOutcome,
            prevHash: prevHash,
            recordHash: recordHash,
            deliveryStatus: .pending,
            remoteAckTimestamp: nil,
            hostIdentifier: identity.hostIdentifier,
            serverVersion: serverVersion,
            durationMs: draft.durationMs,
            rejectionReason: draft.rejectionReason,
            deniedApp: draft.deniedApp,
            scriptErrorCode: draft.scriptErrorCode
        )
    }

    private func buildRecord(from draft: AuditRecordDraft, persistFailed: Bool) -> AuditRecord {
        let stub = makeRecord(from: draft, prevHash: lastRecordHash, recordHash: "")
        let hash = (try? stub.computeRecordHash()) ?? ""
        return AuditRecord(
            recordId: stub.recordId,
            timestampIso8601: stub.timestampIso8601,
            eventType: stub.eventType,
            scriptSha256: stub.scriptSha256,
            targetAppsExtracted: stub.targetAppsExtracted,
            filterDisposition: stub.filterDisposition,
            executionOutcome: stub.executionOutcome,
            prevHash: stub.prevHash,
            recordHash: hash,
            deliveryStatus: persistFailed ? .failed : .pending,
            remoteAckTimestamp: nil,
            hostIdentifier: stub.hostIdentifier,
            serverVersion: stub.serverVersion,
            auditSchemaVersion: stub.auditSchemaVersion,
            durationMs: stub.durationMs,
            rejectionReason: stub.rejectionReason,
            deniedApp: stub.deniedApp,
            scriptErrorCode: stub.scriptErrorCode
        )
    }

    /// Fire-and-forget remote ship. Annotates the local record with
    /// the ack timestamp on success; on timeout/failure, leaves
    /// delivery_status=pending so the next retry picks it up.
    private func scheduleShip(_ record: AuditRecord) {
        let sink = self.remoteSink
        let storage = self.storage
        let timeout = self.config.ackTimeoutMs

        Task.detached(priority: .utility) {
            do {
                let ack = try await sink.ship(record, timeoutMs: timeout)
                let entry = AuditAckEntry(
                    recordId: record.recordId,
                    deliveryStatus: .acknowledged,
                    remoteAckTimestamp: AuditTimestamp.format(ack),
                    appendedAt: AuditTimestamp.format(Date())
                )
                try? storage.appendAck(entry)
            } catch {
                let entry = AuditAckEntry(
                    recordId: record.recordId,
                    deliveryStatus: .pending,
                    remoteAckTimestamp: nil,
                    appendedAt: AuditTimestamp.format(Date())
                )
                try? storage.appendAck(entry)
            }
        }
    }
}

// MARK: - In-memory recorder (tests, dev)

/// Lightweight recorder that hash-chains records in memory only. No
/// remote sink, no persistent storage. Useful for tests that exercise
/// the call-site contract without standing up a FileAuditStorage.
public final class InMemoryAuditRecorder: AuditRecording, @unchecked Sendable {

    public let identity: AuditInstallIdentity
    public let serverVersion: String

    private let storage: InMemoryAuditStorage
    private let queue = DispatchQueue(label: "com.macoscontrol.audit.in-memory-recorder")
    private var lastRecordHash: String

    /// Snapshot accessor that mirrors STORY-006's `records` property.
    /// Returns the merged view (with ack annotations) via the
    /// underlying storage.
    public var records: [AuditRecord] { storage.allRecords() }

    public init(
        identity: AuditInstallIdentity = AuditInstallIdentity(
            hostIdentifier: "in-memory-host",
            installUuid: "in-memory-install"
        ),
        serverVersion: String = auditDefaultServerVersion
    ) {
        self.identity = identity
        self.serverVersion = serverVersion
        self.storage = InMemoryAuditStorage()
        self.lastRecordHash = identity.genesisHashHex
    }

    @discardableResult
    public func record(_ draft: AuditRecordDraft) -> AuditRecord {
        queue.sync {
            let prev = lastRecordHash
            let stub = AuditRecord(
                recordId: UUID(),
                timestampIso8601: AuditTimestamp.format(draft.timestamp),
                eventType: draft.eventType,
                scriptSha256: draft.scriptSha256,
                targetAppsExtracted: draft.targetApps,
                filterDisposition: draft.filterDisposition,
                executionOutcome: draft.executionOutcome,
                prevHash: prev,
                recordHash: "",
                deliveryStatus: .pending,
                remoteAckTimestamp: nil,
                hostIdentifier: identity.hostIdentifier,
                serverVersion: serverVersion,
                durationMs: draft.durationMs,
                rejectionReason: draft.rejectionReason,
                deniedApp: draft.deniedApp,
                scriptErrorCode: draft.scriptErrorCode
            )
            let hash = (try? stub.computeRecordHash()) ?? ""
            let finalized = AuditRecord(
                recordId: stub.recordId,
                timestampIso8601: stub.timestampIso8601,
                eventType: stub.eventType,
                scriptSha256: stub.scriptSha256,
                targetAppsExtracted: stub.targetAppsExtracted,
                filterDisposition: stub.filterDisposition,
                executionOutcome: stub.executionOutcome,
                prevHash: stub.prevHash,
                recordHash: hash,
                deliveryStatus: stub.deliveryStatus,
                remoteAckTimestamp: stub.remoteAckTimestamp,
                hostIdentifier: stub.hostIdentifier,
                serverVersion: stub.serverVersion,
                auditSchemaVersion: stub.auditSchemaVersion,
                durationMs: stub.durationMs,
                rejectionReason: stub.rejectionReason,
                deniedApp: stub.deniedApp,
                scriptErrorCode: stub.scriptErrorCode
            )
            try? storage.insert(finalized)
            lastRecordHash = finalized.recordHash
            return finalized
        }
    }

    @discardableResult
    public func append(_ record: AuditRecord) throws -> AuditRecord {
        try queue.sync {
            try storage.insert(record)
            lastRecordHash = record.recordHash
            return record
        }
    }
}
