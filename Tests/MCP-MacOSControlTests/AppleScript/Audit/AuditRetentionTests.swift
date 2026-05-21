// STORY-024 — Retention sweep tests.
// Mirrors the BDD scenarios in §2 ("Retention", "Records moved to
// archive remain chain-verifiable", "force_rotate_unacked").

import XCTest
@testable import MacOSControlLib

final class AuditRetentionTests: XCTestCase {

    var storage: FakeAuditStorage!
    var clock: FakeClock!
    var identity: AuditInstallIdentity!
    var verifier: AuditChainVerifier!
    var sweeper: AuditRetentionSweeper!

    override func setUp() {
        super.setUp()
        storage = FakeAuditStorage()
        clock = FakeClock(start: Date(timeIntervalSince1970: 1_716_000_000))
        identity = AuditInstallIdentity(hostIdentifier: "test-host",
                                        installUuid: "test-uuid")
        verifier = AuditChainVerifier(storage: storage, identity: identity)
        sweeper = AuditRetentionSweeper(
            storage: storage,
            verifier: verifier,
            clock: clock,
            retentionDays: 365
        )
    }

    func test_sweep_movesOldAcknowledgedRecordsToArchive() throws {
        let oldDate = clock.now().addingTimeInterval(-400 * 86_400)
        let newDate = clock.now().addingTimeInterval(-30 * 86_400)
        try insert(makeRecord(at: oldDate, status: .acknowledged))
        try insert(makeRecord(at: newDate, status: .acknowledged))

        let result = try sweeper.sweep()

        XCTAssertEqual(result.recordsMoved, 1)
        XCTAssertEqual(storage.archived.count, 1)
        XCTAssertEqual(storage.active.count, 1)
    }

    func test_sweep_doesNotDeletePendingRecords_evenWhenOld() throws {
        let oldDate = clock.now().addingTimeInterval(-400 * 86_400)
        try insert(makeRecord(at: oldDate, status: .pending))

        let result = try sweeper.sweep()

        XCTAssertEqual(result.recordsMoved, 0)
        XCTAssertEqual(result.recordsRetainedPending, 1)
        XCTAssertEqual(storage.active.count, 1, "Pending records must not rotate")
        XCTAssertEqual(storage.archived.count, 0)
    }

    func test_sweep_keepsRecentRecords() throws {
        let recent = clock.now().addingTimeInterval(-30 * 86_400)
        try insert(makeRecord(at: recent, status: .acknowledged))

        let result = try sweeper.sweep()

        XCTAssertEqual(result.recordsMoved, 0)
        XCTAssertEqual(storage.active.count, 1)
        XCTAssertEqual(storage.archived.count, 0)
    }

    // MARK: - Force-rotate-unacked (operator escape hatch)

    func test_forceRotateUnacked_rotatesPendingRecords() throws {
        let oldDate = clock.now().addingTimeInterval(-400 * 86_400)
        try insert(makeRecord(at: oldDate, status: .pending))

        let result = try sweeper.forceRotateUnacked()

        XCTAssertEqual(result.recordsMoved, 1)
        XCTAssertEqual(storage.archived.count, 1)
    }

    func test_forceRotateUnacked_doesNotRotateRecentRecords() throws {
        let recent = clock.now().addingTimeInterval(-30 * 86_400)
        try insert(makeRecord(at: recent, status: .pending))

        let result = try sweeper.forceRotateUnacked()

        XCTAssertEqual(result.recordsMoved, 0)
        XCTAssertEqual(storage.active.count, 1)
    }

    // MARK: - Helpers

    private func insert(_ record: AuditRecord) throws {
        try storage.insert(record)
    }

    private var lastHash: String = ""

    /// Build a chain-valid record. Each call appends to a per-test
    /// running chain head so the verifier can walk the active set
    /// without producing a chain break artifact during the test.
    private func makeRecord(
        at date: Date,
        status: AuditDeliveryStatus
    ) -> AuditRecord {
        let prev = lastHash.isEmpty ? identity.genesisHashHex : lastHash
        let stub = AuditRecord(
            recordId: UUID(),
            timestampIso8601: AuditTimestamp.format(date),
            eventType: .applescriptExecute,
            scriptSha256: "abc",
            targetAppsExtracted: [],
            filterDisposition: .allowed,
            executionOutcome: .success,
            prevHash: prev,
            recordHash: "",
            deliveryStatus: status,
            remoteAckTimestamp: status == .acknowledged
                ? AuditTimestamp.format(date.addingTimeInterval(0.5))
                : nil,
            hostIdentifier: identity.hostIdentifier,
            serverVersion: "1.0.0",
            durationMs: 0
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
        lastHash = finalized.recordHash
        return finalized
    }
}
