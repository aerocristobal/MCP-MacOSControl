import Foundation
@testable import MacOSControlLib

/// In-memory storage spy used by the STORY-024 chain + retention tests.
/// Provides a `mutate(_:_:)` test hook so tamper-detection tests can
/// simulate an attacker rewriting a record on disk.
final class FakeAuditStorage: AuditStorage, @unchecked Sendable {

    private let queue = DispatchQueue(label: "fake-audit-storage")
    private(set) var active: [AuditRecord] = []
    private(set) var archived: [AuditRecord] = []
    private var acks: [UUID: AuditAckEntry] = [:]

    func insert(_ record: AuditRecord) throws {
        try queue.sync {
            if active.contains(where: { $0.recordId == record.recordId })
                || archived.contains(where: { $0.recordId == record.recordId }) {
                throw AuditLogImmutabilityViolation(recordId: record.recordId)
            }
            active.append(record)
        }
    }

    func appendAck(_ entry: AuditAckEntry) throws {
        queue.sync {
            if let existing = acks[entry.recordId],
               existing.deliveryStatus == .acknowledged,
               entry.deliveryStatus != .acknowledged {
                return
            }
            acks[entry.recordId] = entry
        }
    }

    func read(_ recordId: UUID) -> AuditRecord? {
        queue.sync {
            let all = active + archived
            guard let raw = all.first(where: { $0.recordId == recordId }) else { return nil }
            if let ack = acks[recordId] {
                return raw.annotated(deliveryStatus: ack.deliveryStatus,
                                     remoteAckTimestamp: ack.remoteAckTimestamp)
            }
            return raw
        }
    }

    func allRecords() -> [AuditRecord] {
        queue.sync { merge(records: archived + active) }
    }

    func activeRecords() -> [AuditRecord] {
        queue.sync { merge(records: active) }
    }

    func archivedRecords() -> [AuditRecord] {
        queue.sync { merge(records: archived) }
    }

    func moveToArchive(_ records: [AuditRecord]) throws {
        queue.sync {
            let ids = Set(records.map { $0.recordId })
            let toMove = active.filter { ids.contains($0.recordId) }
            active.removeAll { ids.contains($0.recordId) }
            archived.append(contentsOf: toMove)
        }
    }

    // MARK: - Test-only tamper injection

    /// Replace the stored record matching `recordId` with the result
    /// of `transform`. Simulates an attacker rewriting a record on
    /// disk — the chain verifier should detect this.
    func mutate(_ recordId: UUID, _ transform: (AuditRecord) -> AuditRecord) {
        queue.sync {
            if let i = active.firstIndex(where: { $0.recordId == recordId }) {
                active[i] = transform(active[i])
            } else if let i = archived.firstIndex(where: { $0.recordId == recordId }) {
                archived[i] = transform(archived[i])
            }
        }
    }

    private func merge(records: [AuditRecord]) -> [AuditRecord] {
        records.map { r in
            if let ack = acks[r.recordId] {
                return r.annotated(deliveryStatus: ack.deliveryStatus,
                                   remoteAckTimestamp: ack.remoteAckTimestamp)
            }
            return r
        }
    }
}
