// STORY-024 — FileAuditStorage I/O tests.
//
// Exercises the on-disk path: file creation, append-only enforcement,
// daily filename rotation, archive moves, ack-ledger merge, and
// round-trip-decode correctness.

import XCTest
@testable import MacOSControlLib

final class FileAuditStorageTests: XCTestCase {

    var tempDir: URL!
    var storage: FileAuditStorage!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit-test-\(UUID().uuidString)", isDirectory: true)
        storage = try! FileAuditStorage(logDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func test_insert_writesRecordToJsonlFile() throws {
        let r = makeRecord(id: UUID(), sha: "abc")
        try storage.insert(r)
        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        XCTAssertEqual(files.filter { $0.hasPrefix("audit-") && $0.hasSuffix(".jsonl") }.count, 1)
        let read = storage.read(r.recordId)
        XCTAssertEqual(read?.scriptSha256, "abc")
    }

    func test_insert_throws_onDuplicateRecordId() throws {
        let r = makeRecord(id: UUID(), sha: "abc")
        try storage.insert(r)
        XCTAssertThrowsError(try storage.insert(r)) { error in
            XCTAssertTrue(error is AuditLogImmutabilityViolation)
        }
    }

    func test_allRecords_returnsRecordsInAppendOrder() throws {
        let r1 = makeRecord(id: UUID(), sha: "a")
        let r2 = makeRecord(id: UUID(), sha: "b")
        let r3 = makeRecord(id: UUID(), sha: "c")
        try storage.insert(r1)
        try storage.insert(r2)
        try storage.insert(r3)
        let all = storage.allRecords()
        XCTAssertEqual(all.map { $0.scriptSha256 }, ["a", "b", "c"])
    }

    func test_appendAck_mergesIntoSubsequentReads() throws {
        let r = makeRecord(id: UUID(), sha: "abc")
        try storage.insert(r)
        try storage.appendAck(AuditAckEntry(
            recordId: r.recordId,
            deliveryStatus: .acknowledged,
            remoteAckTimestamp: "2026-05-20T12:00:00.000Z",
            appendedAt: "2026-05-20T12:00:00.001Z"
        ))
        let read = storage.read(r.recordId)
        XCTAssertEqual(read?.deliveryStatus, .acknowledged)
        XCTAssertEqual(read?.remoteAckTimestamp, "2026-05-20T12:00:00.000Z")
    }

    func test_appendAck_acknowledgedSupersedesLatePending() throws {
        let r = makeRecord(id: UUID(), sha: "abc")
        try storage.insert(r)
        // First the success ack.
        try storage.appendAck(AuditAckEntry(
            recordId: r.recordId,
            deliveryStatus: .acknowledged,
            remoteAckTimestamp: "2026-05-20T12:00:00.000Z",
            appendedAt: "2026-05-20T12:00:00.001Z"
        ))
        // Then a later "still pending" tick from a retry loop.
        try storage.appendAck(AuditAckEntry(
            recordId: r.recordId,
            deliveryStatus: .pending,
            remoteAckTimestamp: nil,
            appendedAt: "2026-05-20T12:00:01.000Z"
        ))
        // Acknowledged must win regardless of timestamp.
        XCTAssertEqual(storage.read(r.recordId)?.deliveryStatus, .acknowledged)
    }

    func test_moveToArchive_movesRecords_andPreservesAllRecordsView() throws {
        let r1 = makeRecord(id: UUID(), sha: "a")
        let r2 = makeRecord(id: UUID(), sha: "b")
        try storage.insert(r1)
        try storage.insert(r2)
        try storage.moveToArchive([r1])
        XCTAssertEqual(storage.activeRecords().count, 1)
        XCTAssertEqual(storage.archivedRecords().count, 1)
        XCTAssertEqual(storage.allRecords().count, 2)
    }

    func test_storage_loadsIndexFromDisk_acrossInstances() throws {
        let r1 = makeRecord(id: UUID(), sha: "a")
        try storage.insert(r1)
        // Spin up a fresh storage pointing at the same directory.
        let storage2 = try FileAuditStorage(logDirectory: tempDir)
        XCTAssertNotNil(storage2.read(r1.recordId))
        // Re-inserting the same record_id must still fail across
        // instances — append-only enforcement is durable, not just
        // in-memory.
        XCTAssertThrowsError(try storage2.insert(r1)) { error in
            XCTAssertTrue(error is AuditLogImmutabilityViolation)
        }
    }

    // MARK: - Helpers

    private func makeRecord(id: UUID, sha: String) -> AuditRecord {
        AuditRecord(
            recordId: id,
            timestampIso8601: AuditTimestamp.format(Date()),
            eventType: .applescriptExecute,
            scriptSha256: sha,
            targetAppsExtracted: [],
            filterDisposition: .allowed,
            executionOutcome: .success,
            prevHash: String(repeating: "0", count: 64),
            recordHash: String(repeating: "f", count: 64),
            deliveryStatus: .pending,
            remoteAckTimestamp: nil,
            hostIdentifier: "test-host",
            serverVersion: "1.0.0",
            durationMs: 0
        )
    }
}
