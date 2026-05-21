// STORY-024 — Background maintenance loop tests.
//
// Covers the BDD scenarios this loop closes:
//
//   * "Remote destination outage does not lose records — when the
//     destination recovers, pending records are flushed in order
//     and each flushed record is annotated with its acknowledgment
//     timestamp."

import XCTest
@testable import MacOSControlLib

final class AuditMaintenanceTests: XCTestCase {

    var storage: FakeAuditStorage!
    var sink: FakeAuditRemoteSink!
    var recorder: AuditRecorder!
    var sweeper: AuditRetentionSweeper!
    var verifier: AuditChainVerifier!
    var identity: AuditInstallIdentity!
    var config: AuditConfig!
    var loop: AuditMaintenanceLoop!

    override func setUp() {
        super.setUp()
        storage = FakeAuditStorage()
        sink = FakeAuditRemoteSink()
        identity = AuditInstallIdentity(
            hostIdentifier: "maint-host",
            installUuid: "maint-uuid"
        )
        config = AuditConfig(
            logDirectory: URL(fileURLWithPath: NSTemporaryDirectory()),
            retentionDays: 365,
            remoteSinkKind: .oslog,
            remoteSinkURL: nil,
            ackTimeoutMs: 5000,
            hostIdentifierOverride: identity.hostIdentifier,
            installUuidOverride: identity.installUuid,
            adminToolsEnabled: false
        )
        recorder = AuditRecorder(
            storage: storage,
            remoteSink: sink,
            config: config,
            identity: identity
        )
        verifier = AuditChainVerifier(storage: storage, identity: identity)
        sweeper = AuditRetentionSweeper(
            storage: storage,
            verifier: verifier,
            clock: SystemClock(),
            retentionDays: 365
        )
        loop = AuditMaintenanceLoop(
            storage: storage,
            remoteSink: sink,
            sweeper: sweeper,
            config: config,
            retryIntervalSeconds: 60
        )
    }

    func test_retryPendingOnce_flushesPendingRecordsInOrder_whenSinkRecovers() async throws {
        // Outage: every ship attempt fails.
        sink.shouldFail = true
        let r1 = recorder.record(makeDraft("a"))
        let r2 = recorder.record(makeDraft("b"))
        let r3 = recorder.record(makeDraft("c"))

        // Let the initial fire-and-forget ships fail and mark each
        // record's delivery_status=pending.
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(storage.read(r1.recordId)?.deliveryStatus, .pending)
        XCTAssertEqual(storage.read(r2.recordId)?.deliveryStatus, .pending)
        XCTAssertEqual(storage.read(r3.recordId)?.deliveryStatus, .pending)
        XCTAssertEqual(sink.shippedRecords.count, 0)

        // Destination recovers.
        sink.shouldFail = false

        // Retry loop flushes pending records.
        let flushed = await loop.retryPendingOnce()
        XCTAssertEqual(flushed, 3)

        // All records acknowledged and annotated.
        for r in [r1, r2, r3] {
            let stored = storage.read(r.recordId)
            XCTAssertEqual(stored?.deliveryStatus, .acknowledged,
                           "record \(r.scriptSha256) must be acknowledged after retry")
            XCTAssertNotNil(stored?.remoteAckTimestamp)
        }

        // Records shipped in append order.
        XCTAssertEqual(sink.shippedRecords.map(\.recordId), [r1.recordId, r2.recordId, r3.recordId])
    }

    func test_retryPendingOnce_stopsAtFirstFailure_toPreserveOrder() async throws {
        sink.shouldFail = true
        let r1 = recorder.record(makeDraft("a"))
        let r2 = recorder.record(makeDraft("b"))
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(storage.read(r1.recordId)?.deliveryStatus, .pending)
        XCTAssertEqual(storage.read(r2.recordId)?.deliveryStatus, .pending)

        // Sink stays down — retry should flush nothing and not throw.
        let flushed = await loop.retryPendingOnce()
        XCTAssertEqual(flushed, 0)
        XCTAssertEqual(storage.read(r1.recordId)?.deliveryStatus, .pending)
    }

    func test_retryPendingOnce_skipsAlreadyAcknowledgedRecords() async throws {
        sink.shouldFail = false
        let r1 = recorder.record(makeDraft("a"))
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(storage.read(r1.recordId)?.deliveryStatus, .acknowledged)

        // Running the retry pass should ship nothing (already acked).
        let beforeCount = sink.shippedRecords.count
        let flushed = await loop.retryPendingOnce()
        XCTAssertEqual(flushed, 0)
        XCTAssertEqual(sink.shippedRecords.count, beforeCount)
    }

    private func makeDraft(_ sha: String) -> AuditRecordDraft {
        AuditRecordDraft(
            eventType: .applescriptExecute,
            scriptSha256: sha,
            targetApps: [],
            filterDisposition: .allowed,
            executionOutcome: .success,
            durationMs: 0
        )
    }
}
