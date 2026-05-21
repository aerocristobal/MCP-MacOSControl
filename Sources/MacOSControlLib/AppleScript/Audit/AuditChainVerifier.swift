// STORY-024 — Hash chain verification.
//
// The chain is verified by walking records in append order and
// confirming that each record's prev_hash equals the prior record's
// record_hash, AND that each record's record_hash equals the
// recomputed canonical-JSON SHA-256. The first record's prev_hash
// must match the per-install genesis (host_identifier + install_uuid).
//
// On a break, the verifier reports the FIRST record where the chain
// disagreed — that's the earliest forensic evidence of tampering.

import Foundation

public struct AuditChainVerificationReport: Equatable {
    public let isValid: Bool
    public let firstBreakAt: UUID?
    public let affectedRange: AffectedRange?
    public let totalChecked: Int
    public let summary: String

    /// First and last record IDs in the affected range (inclusive).
    /// Uses two UUIDs rather than ClosedRange<UUID> because UUID is
    /// not Comparable.
    public struct AffectedRange: Equatable {
        public let lowerBound: UUID
        public let upperBound: UUID
        public init(lowerBound: UUID, upperBound: UUID) {
            self.lowerBound = lowerBound
            self.upperBound = upperBound
        }
    }
}

public final class AuditChainVerifier {

    private let storage: AuditStorage
    private let identity: AuditInstallIdentity

    public init(storage: AuditStorage, identity: AuditInstallIdentity) {
        self.storage = storage
        self.identity = identity
    }

    /// Walk all records (active + archive) in order and verify the
    /// chain.
    public func verify() -> AuditChainVerificationReport {
        verify(records: storage.allRecords())
    }

    /// Verify only the active records (used by the retention sweeper
    /// before it moves records — to make sure the active chain is
    /// intact before touching anything).
    public func verifyActive() -> AuditChainVerificationReport {
        verify(records: storage.activeRecords())
    }

    /// Verify the combined active + archive set after a sweep.
    /// Confirms the chain is still unbroken across the move.
    public func verifyAcrossSets() -> AuditChainVerificationReport {
        let combined = storage.archivedRecords() + storage.activeRecords()
        return verify(records: combined)
    }

    private func verify(records: [AuditRecord]) -> AuditChainVerificationReport {
        guard !records.isEmpty else {
            return AuditChainVerificationReport(
                isValid: true,
                firstBreakAt: nil,
                affectedRange: nil,
                totalChecked: 0,
                summary: "empty chain"
            )
        }

        let genesis = identity.genesisHashHex
        var expectedPrev = genesis

        for (idx, rec) in records.enumerated() {
            // Check prev_hash linkage.
            if rec.prevHash != expectedPrev {
                let last = records.last!.recordId
                return AuditChainVerificationReport(
                    isValid: false,
                    firstBreakAt: rec.recordId,
                    affectedRange: .init(lowerBound: rec.recordId, upperBound: last),
                    totalChecked: idx + 1,
                    summary: "prev_hash mismatch at record \(rec.recordId.uuidString): expected \(expectedPrev), got \(rec.prevHash)"
                )
            }
            // Check the record's self-hash.
            let recomputed = (try? rec.computeRecordHash()) ?? ""
            if rec.recordHash != recomputed {
                let last = records.last!.recordId
                return AuditChainVerificationReport(
                    isValid: false,
                    firstBreakAt: rec.recordId,
                    affectedRange: .init(lowerBound: rec.recordId, upperBound: last),
                    totalChecked: idx + 1,
                    summary: "record_hash mismatch at record \(rec.recordId.uuidString): stored \(rec.recordHash), recomputed \(recomputed)"
                )
            }
            expectedPrev = rec.recordHash
        }

        return AuditChainVerificationReport(
            isValid: true,
            firstBreakAt: nil,
            affectedRange: nil,
            totalChecked: records.count,
            summary: "ok"
        )
    }
}
