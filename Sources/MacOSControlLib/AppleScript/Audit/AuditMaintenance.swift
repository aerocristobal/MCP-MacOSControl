// STORY-024 — Background maintenance loops.
//
// Two loops run continuously while the server is up:
//
//   1. retryPendingLoop()  — every `retryIntervalSeconds`, scan for
//      records whose latest delivery status is .pending and re-ship
//      them in append order. Closes the BDD scenario "Remote
//      destination outage does not lose records — when the destination
//      recovers, pending records are flushed in order."
//
//   2. dailySweepLoop()   — runs the retention sweep every 24 hours.
//      Closes the DoD item "AuditRetentionSweeper runs daily."
//
// Both loops are best-effort and self-recovering: a failed retry
// leaves the record pending for the next pass; a failed sweep logs
// and tries again the next day. Neither loop is expected to terminate
// short of process exit.

import Foundation

public final class AuditMaintenanceLoop: @unchecked Sendable {

    private let storage: AuditStorage
    private let remoteSink: AuditRemoteSink
    private let sweeper: AuditRetentionSweeper
    private let config: AuditConfig
    private let clock: Clock

    /// How often the retry loop wakes up. Default 60s — quick enough
    /// that "outage recovers, records flush" feels prompt; slow enough
    /// that a sustained outage doesn't burn CPU.
    public let retryIntervalSeconds: Int

    public init(
        storage: AuditStorage,
        remoteSink: AuditRemoteSink,
        sweeper: AuditRetentionSweeper,
        config: AuditConfig,
        clock: Clock = SystemClock(),
        retryIntervalSeconds: Int = 60
    ) {
        self.storage = storage
        self.remoteSink = remoteSink
        self.sweeper = sweeper
        self.config = config
        self.clock = clock
        self.retryIntervalSeconds = retryIntervalSeconds
    }

    /// Start both loops as detached Tasks. Idempotent — safe to call
    /// once at startup; subsequent calls spawn additional loops which
    /// the caller probably doesn't want.
    public func start() {
        Task.detached(priority: .utility) { [weak self] in
            await self?.retryPendingLoop()
        }
        Task.detached(priority: .utility) { [weak self] in
            await self?.dailySweepLoop()
        }
    }

    /// Single pass over pending records, ordered by append (which is
    /// `allRecords()`'s natural order). Called by the loop but also
    /// exposed for tests that want to trigger a retry without waiting.
    @discardableResult
    public func retryPendingOnce() async -> Int {
        let records = storage.allRecords()
        var flushed = 0
        for r in records where r.deliveryStatus == .pending {
            do {
                let ack = try await remoteSink.ship(r, timeoutMs: config.ackTimeoutMs)
                let entry = AuditAckEntry(
                    recordId: r.recordId,
                    deliveryStatus: .acknowledged,
                    remoteAckTimestamp: AuditTimestamp.format(ack),
                    appendedAt: AuditTimestamp.format(Date())
                )
                try? storage.appendAck(entry)
                flushed += 1
            } catch {
                // Still pending — stop the in-order flush so later
                // pending records don't get out-of-order acks while
                // the destination is still failing.
                break
            }
        }
        return flushed
    }

    private func retryPendingLoop() async {
        while !Task.isCancelled {
            _ = await retryPendingOnce()
            await clock.sleep(forMilliseconds: retryIntervalSeconds * 1_000)
        }
    }

    private func dailySweepLoop() async {
        while !Task.isCancelled {
            // Sleep first so we don't double-sweep at startup (server
            // already runs verify() on cold start).
            await clock.sleep(forMilliseconds: 24 * 60 * 60 * 1_000)
            do {
                _ = try sweeper.sweep()
            } catch {
                MCPLogger.warn("Daily retention sweep failed: \(error)")
            }
        }
    }
}
