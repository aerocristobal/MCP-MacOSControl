// STORY-024 — Retention sweep.
//
// Daily sweep moves records older than `retentionDays` from active
// to archive — but ONLY if the record's delivery_status is
// .acknowledged. Pending records never rotate: silent log loss during
// a destination outage is the worst possible audit failure mode (see
// story §9). The ForceRotateUnackedTool admin tool is the documented
// exception, gated by MCP_MACOS_CONTROL_AUDIT_ADMIN_ENABLED=true.
//
// After moving, the sweeper re-verifies the chain across the combined
// active+archive set; a verification failure is logged at CRITICAL
// level so operators see it on cold inspection of `log show`.

import Foundation

public final class AuditRetentionSweeper {

    private let storage: AuditStorage
    private let verifier: AuditChainVerifier
    private let clock: Clock
    public let retentionDays: Int

    public init(
        storage: AuditStorage,
        verifier: AuditChainVerifier,
        clock: Clock,
        retentionDays: Int
    ) {
        self.storage = storage
        self.verifier = verifier
        self.clock = clock
        self.retentionDays = retentionDays
    }

    public struct SweepResult: Equatable {
        public let recordsMoved: Int
        public let recordsRetainedPending: Int
        public let chainVerified: Bool
        public init(recordsMoved: Int, recordsRetainedPending: Int, chainVerified: Bool) {
            self.recordsMoved = recordsMoved
            self.recordsRetainedPending = recordsRetainedPending
            self.chainVerified = chainVerified
        }
    }

    /// Normal sweep: move acknowledged + old; leave pending in place.
    @discardableResult
    public func sweep() throws -> SweepResult {
        let cutoff = clock.now().addingTimeInterval(-TimeInterval(retentionDays) * 86_400)
        let active = storage.activeRecords()

        var toMove: [AuditRecord] = []
        var pendingHeldBack = 0
        for r in active {
            guard let ts = AuditTimestamp.parse(r.timestampIso8601), ts < cutoff else { continue }
            if r.deliveryStatus == .acknowledged {
                toMove.append(r)
            } else {
                pendingHeldBack += 1
            }
        }

        try storage.moveToArchive(toMove)
        let report = verifier.verifyAcrossSets()
        if !report.isValid {
            MCPLogger.error(
                "SECURITY-CRITICAL: audit chain verification failed after retention sweep — \(report.summary)"
            )
        }
        return SweepResult(
            recordsMoved: toMove.count,
            recordsRetainedPending: pendingHeldBack,
            chainVerified: report.isValid
        )
    }

    /// Operator-initiated force rotation of unacknowledged old records.
    /// Documented escape hatch when a destination outage has lasted
    /// long enough that the operator accepts the loss.
    @discardableResult
    public func forceRotateUnacked() throws -> SweepResult {
        let cutoff = clock.now().addingTimeInterval(-TimeInterval(retentionDays) * 86_400)
        let active = storage.activeRecords()

        let toMove = active.filter { rec in
            guard let ts = AuditTimestamp.parse(rec.timestampIso8601), ts < cutoff else { return false }
            return rec.deliveryStatus != .acknowledged
        }

        try storage.moveToArchive(toMove)
        let report = verifier.verifyAcrossSets()
        if !report.isValid {
            MCPLogger.error(
                "SECURITY-CRITICAL: audit chain verification failed after force-rotate-unacked — \(report.summary)"
            )
        }
        return SweepResult(
            recordsMoved: toMove.count,
            recordsRetainedPending: 0,
            chainVerified: report.isValid
        )
    }
}
