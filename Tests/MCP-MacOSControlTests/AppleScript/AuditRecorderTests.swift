// STORY-006 — run_applescript MCP Tool
// COMPONENT: AuditRecorder protocol + InMemoryAuditRecorder + ScriptHasher

import XCTest
@testable import MacOSControlLib

final class InMemoryAuditRecorderTests: XCTestCase {

    var recorder: InMemoryAuditRecorder!

    override func setUp() {
        super.setUp()
        recorder = InMemoryAuditRecorder()
    }

    func test_record_storesRecord() {
        let record = AuditRecord(
            timestamp: Date(),
            toolName: "run_applescript",
            scriptSha256: "abc123",
            scriptSource: nil,
            outcome: .success,
            durationMs: 42,
            targetApps: ["Finder"]
        )

        recorder.record(record)

        XCTAssertEqual(recorder.records.count, 1)
        XCTAssertEqual(recorder.records.first?.scriptSha256, "abc123")
    }

    func test_record_storesMultipleRecords_inOrder() {
        let r1 = makeRecord(sha: "aaa", outcome: .success)
        let r2 = makeRecord(sha: "bbb", outcome: .timeout)
        let r3 = makeRecord(sha: "ccc", outcome: .securityRejected(reason: "do_shell_script"))

        recorder.record(r1)
        recorder.record(r2)
        recorder.record(r3)

        XCTAssertEqual(recorder.records.map { $0.scriptSha256 }, ["aaa", "bbb", "ccc"])
    }

    func test_record_redactsSourceWhenNil() {
        let record = makeRecord(sha: "abc", outcome: .success, source: nil)
        recorder.record(record)
        XCTAssertNil(recorder.records.first?.scriptSource)
    }

    func test_record_capturesSourceWhenProvided() {
        let record = makeRecord(sha: "abc", outcome: .success, source: "tell app Finder to get name")
        recorder.record(record)
        XCTAssertEqual(recorder.records.first?.scriptSource, "tell app Finder to get name")
    }

    private func makeRecord(
        sha: String,
        outcome: AuditOutcome,
        source: String? = nil
    ) -> AuditRecord {
        AuditRecord(
            timestamp: Date(),
            toolName: "run_applescript",
            scriptSha256: sha,
            scriptSource: source,
            outcome: outcome,
            durationMs: 0,
            targetApps: []
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
        // Verify against the known SHA-256 of "hello"
        XCTAssertEqual(hash, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }
}
