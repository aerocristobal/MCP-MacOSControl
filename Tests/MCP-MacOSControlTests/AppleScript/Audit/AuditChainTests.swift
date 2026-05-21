// STORY-024 — Hash chain integrity tests.
// Mirrors the BDD scenarios in §2 ("Tamper evidence", "Append-only").

import XCTest
import CryptoKit
@testable import MacOSControlLib

final class AuditChainTests: XCTestCase {

    var storage: FakeAuditStorage!
    var sink: FakeAuditRemoteSink!
    var recorder: AuditRecorder!
    var identity: AuditInstallIdentity!

    override func setUp() {
        super.setUp()
        storage = FakeAuditStorage()
        sink = FakeAuditRemoteSink()
        identity = AuditInstallIdentity(hostIdentifier: "test-host",
                                        installUuid: "install-uuid-12345")
        let config = AuditConfig(
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
    }

    // MARK: - Hash Chain (BDD: "Each audit record includes the hash of the prior record")

    func test_writeRecord_setsPrevHashToPriorRecordRecordHash() throws {
        let r1 = recorder.record(makeDraft("abc"))
        let r2 = recorder.record(makeDraft("def"))
        XCTAssertEqual(r2.prevHash, r1.recordHash)
    }

    func test_firstRecord_setsPrevHashToGenesisDerivedFromHostAndInstall() throws {
        let r1 = recorder.record(makeDraft("abc"))
        XCTAssertEqual(r1.prevHash, identity.genesisHashHex)
    }

    func test_threeRecords_chainCorrectly() throws {
        let r1 = recorder.record(makeDraft("a"))
        let r2 = recorder.record(makeDraft("b"))
        let r3 = recorder.record(makeDraft("c"))
        XCTAssertEqual(r1.prevHash, identity.genesisHashHex)
        XCTAssertEqual(r2.prevHash, r1.recordHash)
        XCTAssertEqual(r3.prevHash, r2.recordHash)
    }

    // MARK: - Tamper Detection (BDD: "Tampering with a prior record breaks the chain")

    func test_verify_detectsTampering_atFirstBreak() throws {
        _ = recorder.record(makeDraft("a"))
        let r2 = recorder.record(makeDraft("b"))
        let r3 = recorder.record(makeDraft("c"))

        // Attacker rewrites R2 in storage (changes the script_sha256).
        storage.mutate(r2.recordId) { rec in
            AuditRecord(
                recordId: rec.recordId,
                timestampIso8601: rec.timestampIso8601,
                eventType: rec.eventType,
                scriptSha256: "TAMPERED",
                targetAppsExtracted: rec.targetAppsExtracted,
                filterDisposition: rec.filterDisposition,
                executionOutcome: rec.executionOutcome,
                prevHash: rec.prevHash,
                recordHash: rec.recordHash,
                deliveryStatus: rec.deliveryStatus,
                remoteAckTimestamp: rec.remoteAckTimestamp,
                hostIdentifier: rec.hostIdentifier,
                serverVersion: rec.serverVersion,
                durationMs: rec.durationMs
            )
        }

        let verifier = AuditChainVerifier(storage: storage, identity: identity)
        let report = verifier.verify()
        XCTAssertFalse(report.isValid)
        // The tampered R2's own record_hash no longer matches its
        // (recomputed) canonical JSON — verifier breaks at R2.
        XCTAssertEqual(report.firstBreakAt, r2.recordId)
        XCTAssertEqual(report.affectedRange?.upperBound, r3.recordId)
    }

    func test_verify_succeeds_onUntamperedChain() throws {
        _ = recorder.record(makeDraft("a"))
        _ = recorder.record(makeDraft("b"))
        _ = recorder.record(makeDraft("c"))

        let verifier = AuditChainVerifier(storage: storage, identity: identity)
        let report = verifier.verify()
        XCTAssertTrue(report.isValid)
        XCTAssertNil(report.firstBreakAt)
        XCTAssertEqual(report.totalChecked, 3)
    }

    func test_verify_succeeds_onEmptyChain() throws {
        let verifier = AuditChainVerifier(storage: storage, identity: identity)
        let report = verifier.verify()
        XCTAssertTrue(report.isValid)
        XCTAssertEqual(report.totalChecked, 0)
    }

    /// Mirrors the BDD scenario literally: an attacker who is
    /// sophisticated enough to also recompute and overwrite the
    /// tampered record's own record_hash. The self-hash check at R2
    /// passes (because the attacker did the math); the chain breaks
    /// at R3 because R3's prev_hash still references the *original*
    /// R2.record_hash, not the recomputed one.
    func test_verify_detectsSophisticatedTampering_atR3() throws {
        _ = recorder.record(makeDraft("a"))
        let r2 = recorder.record(makeDraft("b"))
        let r3 = recorder.record(makeDraft("c"))

        // Attacker rewrites R2 AND recomputes record_hash so the self
        // check no longer catches them at R2.
        storage.mutate(r2.recordId) { rec in
            let tampered = AuditRecord(
                recordId: rec.recordId,
                timestampIso8601: rec.timestampIso8601,
                eventType: rec.eventType,
                scriptSha256: "TAMPERED",
                targetAppsExtracted: rec.targetAppsExtracted,
                filterDisposition: rec.filterDisposition,
                executionOutcome: rec.executionOutcome,
                prevHash: rec.prevHash,
                recordHash: rec.recordHash,
                deliveryStatus: rec.deliveryStatus,
                remoteAckTimestamp: rec.remoteAckTimestamp,
                hostIdentifier: rec.hostIdentifier,
                serverVersion: rec.serverVersion,
                durationMs: rec.durationMs
            )
            let newHash = (try? tampered.computeRecordHash()) ?? rec.recordHash
            return AuditRecord(
                recordId: tampered.recordId,
                timestampIso8601: tampered.timestampIso8601,
                eventType: tampered.eventType,
                scriptSha256: tampered.scriptSha256,
                targetAppsExtracted: tampered.targetAppsExtracted,
                filterDisposition: tampered.filterDisposition,
                executionOutcome: tampered.executionOutcome,
                prevHash: tampered.prevHash,
                recordHash: newHash,
                deliveryStatus: tampered.deliveryStatus,
                remoteAckTimestamp: tampered.remoteAckTimestamp,
                hostIdentifier: tampered.hostIdentifier,
                serverVersion: tampered.serverVersion,
                durationMs: tampered.durationMs
            )
        }

        let verifier = AuditChainVerifier(storage: storage, identity: identity)
        let report = verifier.verify()
        XCTAssertFalse(report.isValid)
        // Per the BDD scenario: "verification fails at R3 because
        // R3.prev_hash no longer matches SHA-256(modified R2)."
        XCTAssertEqual(report.firstBreakAt, r3.recordId)
    }

    // MARK: - Archive chain (BDD: "Records moved to archive remain chain-verifiable")

    func test_verifyAcrossSets_succeeds_whenChainSpansActiveAndArchive() throws {
        let r1 = recorder.record(makeDraft("a"))
        let r2 = recorder.record(makeDraft("b"))
        let r3 = recorder.record(makeDraft("c"))
        let r4 = recorder.record(makeDraft("d"))

        // Move the first two records to archive. The chain
        // (R1 → R2 → R3 → R4) must still verify when read as
        // archive + active.
        try storage.moveToArchive([r1, r2])

        let verifier = AuditChainVerifier(storage: storage, identity: identity)
        let report = verifier.verifyAcrossSets()
        XCTAssertTrue(report.isValid, "chain broke after archive move: \(report.summary)")
        XCTAssertEqual(report.totalChecked, 4)

        // Sanity: r3 and r4 are still active; r1 and r2 are archived.
        XCTAssertEqual(storage.archived.map(\.recordId), [r1.recordId, r2.recordId])
        XCTAssertEqual(storage.active.map(\.recordId), [r3.recordId, r4.recordId])
    }

    // MARK: - Append-Only (BDD: "No record is ever modified after write")

    func test_append_throwsImmutabilityViolation_whenSameRecordIdWrittenTwice() throws {
        let r1 = recorder.record(makeDraft("a"))
        XCTAssertThrowsError(try recorder.append(r1)) { error in
            XCTAssertTrue(error is AuditLogImmutabilityViolation)
        }
    }

    // MARK: - Remote Shipping (BDD: "Each audit record is shipped... within 5 seconds")

    func test_write_eventuallyShipsRecordToRemote() async throws {
        _ = recorder.record(makeDraft("a"))
        // Async ship is fire-and-forget; give it time.
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(sink.shippedRecords.count, 1)
    }

    func test_write_annotatesAckTimestamp_afterShipSucceeds() async throws {
        let r = recorder.record(makeDraft("a"))
        // Give the detached ship task a moment to complete and write
        // its ack to storage.
        try await Task.sleep(nanoseconds: 300_000_000)
        let stored = storage.read(r.recordId)
        XCTAssertEqual(stored?.deliveryStatus, .acknowledged)
        XCTAssertNotNil(stored?.remoteAckTimestamp)
    }

    func test_write_leavesDeliveryStatusPending_whenSinkFails() async throws {
        sink.shouldFail = true
        let r = recorder.record(makeDraft("a"))
        try await Task.sleep(nanoseconds: 300_000_000)
        let stored = storage.read(r.recordId)
        XCTAssertEqual(stored?.deliveryStatus, .pending)
        XCTAssertNil(stored?.remoteAckTimestamp)
    }

    // MARK: - Helpers

    private func makeDraft(_ sha: String) -> AuditRecordDraft {
        AuditRecordDraft(
            eventType: .applescriptExecute,
            scriptSha256: sha,
            targetApps: ["Finder"],
            filterDisposition: .allowed,
            executionOutcome: .success,
            durationMs: 0
        )
    }
}
