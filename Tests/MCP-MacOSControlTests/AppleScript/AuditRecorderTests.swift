// STORY-006 + STORY-024 — Audit recorder seam + hash chain.
//
// STORY-006 introduced the protocol seam; STORY-024 added per-record
// hash chaining, an extended schema, and persistent storage. These
// tests exercise the lightweight InMemoryAuditRecorder used in dev/test
// (the production AuditRecorder is covered in AuditChainTests +
// AuditRetentionTests).

import XCTest
@testable import MacOSControlLib

final class InMemoryAuditRecorderTests: XCTestCase {

    var recorder: InMemoryAuditRecorder!

    override func setUp() {
        super.setUp()
        recorder = InMemoryAuditRecorder(
            identity: AuditInstallIdentity(hostIdentifier: "test-host",
                                           installUuid: "test-uuid")
        )
    }

    func test_record_storesRecord() {
        let r = recorder.record(makeDraft(sha: "abc123",
                                          outcome: .success,
                                          disposition: .allowed))
        XCTAssertEqual(recorder.records.count, 1)
        XCTAssertEqual(recorder.records.first?.scriptSha256, "abc123")
        XCTAssertEqual(r.scriptSha256, "abc123")
    }

    func test_record_storesMultipleRecords_inOrder() {
        _ = recorder.record(makeDraft(sha: "aaa", outcome: .success, disposition: .allowed))
        _ = recorder.record(makeDraft(sha: "bbb", outcome: .timeout, disposition: .allowed))
        _ = recorder.record(makeDraft(sha: "ccc",
                                      outcome: .notExecuted,
                                      disposition: .rejectedSecurity,
                                      rejection: "do_shell_script"))
        XCTAssertEqual(recorder.records.map { $0.scriptSha256 }, ["aaa", "bbb", "ccc"])
    }

    func test_record_hashChain_firstRecordPrevHashIsGenesis() {
        let r1 = recorder.record(makeDraft(sha: "a", outcome: .success, disposition: .allowed))
        XCTAssertEqual(r1.prevHash, recorder.identity.genesisHashHex)
    }

    func test_record_hashChain_subsequentPrevHashLinksToPriorRecordHash() {
        let r1 = recorder.record(makeDraft(sha: "a", outcome: .success, disposition: .allowed))
        let r2 = recorder.record(makeDraft(sha: "b", outcome: .success, disposition: .allowed))
        XCTAssertEqual(r2.prevHash, r1.recordHash)
    }

    func test_record_eventType_andFilterDisposition_areSet() {
        let r = recorder.record(makeDraft(sha: "a",
                                          outcome: .notExecuted,
                                          disposition: .rejectedSecurity,
                                          rejection: "do_shell_script"))
        XCTAssertEqual(r.eventType, .applescriptExecute)
        XCTAssertEqual(r.filterDisposition, .rejectedSecurity)
        XCTAssertEqual(r.executionOutcome, .notExecuted)
        XCTAssertEqual(r.rejectionReason, "do_shell_script")
    }

    private func makeDraft(
        sha: String,
        outcome: AuditExecutionOutcome,
        disposition: AuditFilterDisposition,
        rejection: String? = nil
    ) -> AuditRecordDraft {
        AuditRecordDraft(
            eventType: .applescriptExecute,
            scriptSha256: sha,
            targetApps: [],
            filterDisposition: disposition,
            executionOutcome: outcome,
            durationMs: 0,
            rejectionReason: rejection
        )
    }
}

final class ScriptHasherTests: XCTestCase {
    func test_sha256Hex_isStable() {
        let a = ScriptHasher.sha256Hex("return 1")
        let b = ScriptHasher.sha256Hex("return 1")
        XCTAssertEqual(a, b)
    }

    func test_sha256Hex_isDistinctForDifferentInputs() {
        let a = ScriptHasher.sha256Hex("return 1")
        let b = ScriptHasher.sha256Hex("return 2")
        XCTAssertNotEqual(a, b)
    }

    func test_sha256Hex_producesLowercaseHex() {
        let hash = ScriptHasher.sha256Hex("hello")
        XCTAssertEqual(hash.count, 64)
        XCTAssertEqual(hash, hash.lowercased())
        XCTAssertEqual(hash, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }
}
