import Foundation
@testable import MacOSControlLib

/// In-memory spy that hash-chains records the same way the production
/// AuditRecorder does, so tests can assert on prev_hash/record_hash
/// linkage AND on the call-site contract. Conforms to the renamed
/// `AuditRecording` protocol from STORY-024.
final class AuditRecorderSpy: AuditRecording, @unchecked Sendable {

    let identity: AuditInstallIdentity
    let serverVersion: String

    private let queue = DispatchQueue(label: "audit-recorder-spy")
    private(set) var records: [AuditRecord] = []
    private var lastRecordHash: String

    /// Records that were `append`-ed and threw — useful for the
    /// immutability test which expects an error rather than a
    /// successful append.
    private(set) var appendErrors: [Error] = []

    init(
        identity: AuditInstallIdentity = AuditInstallIdentity(
            hostIdentifier: "spy-host",
            installUuid: "spy-install"
        ),
        serverVersion: String = auditDefaultServerVersion
    ) {
        self.identity = identity
        self.serverVersion = serverVersion
        self.lastRecordHash = identity.genesisHashHex
    }

    @discardableResult
    func record(_ draft: AuditRecordDraft) -> AuditRecord {
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
            records.append(finalized)
            lastRecordHash = finalized.recordHash
            return finalized
        }
    }

    @discardableResult
    func append(_ record: AuditRecord) throws -> AuditRecord {
        try queue.sync {
            if records.contains(where: { $0.recordId == record.recordId }) {
                let err = AuditLogImmutabilityViolation(recordId: record.recordId)
                appendErrors.append(err)
                throw err
            }
            records.append(record)
            lastRecordHash = record.recordHash
            return record
        }
    }
}
