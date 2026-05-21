// STORY-024 — End-to-end integration test for the audit subsystem.
//
// Gated by `CI_MACOS_INTEGRATION=true` like the rest of the
// integration suite. Exercises the FULL path:
//   1. AuditRecorder builds a record and writes it to FileAuditStorage
//   2. OSLogAuditSink ships it to the unified log
//   3. `log show --subsystem com.mcp.macos-control.audit` finds it
//
// Skipped automatically in plain `swift test` so PRs stay green.

import XCTest
@testable import MacOSControlLib

final class AuditLogIntegrityTests: IntegrationTestCase {

    func test_endToEnd_recordShippedToOSLog_andOnDisk() async throws {
        guard isIntegrationEnabled else {
            throw XCTSkip("Set CI_MACOS_INTEGRATION=true to run audit integrity integration tests.")
        }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit-integration-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let storage = try FileAuditStorage(logDirectory: dir)
        let sink = OSLogAuditSink()
        let identity = AuditInstallIdentity(
            hostIdentifier: "integration-host",
            installUuid: UUID().uuidString
        )
        let config = AuditConfig(
            logDirectory: dir,
            retentionDays: 365,
            remoteSinkKind: .oslog,
            remoteSinkURL: nil,
            ackTimeoutMs: 5000,
            hostIdentifierOverride: identity.hostIdentifier,
            installUuidOverride: identity.installUuid,
            adminToolsEnabled: false
        )
        let recorder = AuditRecorder(
            storage: storage,
            remoteSink: sink,
            config: config,
            identity: identity
        )

        let sentinel = "integration-\(UUID().uuidString)"
        let draft = AuditRecordDraft(
            eventType: .applescriptExecute,
            scriptSha256: ScriptHasher.sha256Hex(sentinel),
            targetApps: ["Finder"],
            filterDisposition: .allowed,
            executionOutcome: .success,
            durationMs: 1
        )
        let record = recorder.record(draft)

        // Give the detached ship task time to write to OSLog and the
        // ack ledger.
        try await Task.sleep(nanoseconds: 1_500_000_000)

        // Disk side: the record is on disk and (eventually) acked.
        let stored = storage.read(record.recordId)
        XCTAssertEqual(stored?.scriptSha256, record.scriptSha256)

        // OSLog side: the record's script_sha256 appears in `log show`
        // for the audit subsystem.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        task.arguments = [
            "show",
            "--predicate", "subsystem == \"com.mcp.macos-control.audit\"",
            "--last", "30s",
            "--style", "compact"
        ]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        XCTAssertTrue(
            output.contains(record.scriptSha256),
            "expected script_sha256 \(record.scriptSha256) in `log show` output; got \(output.prefix(2_000))"
        )
    }

    // MARK: -

    private var isIntegrationEnabled: Bool {
        ProcessInfo.processInfo.environment["CI_MACOS_INTEGRATION"] == "true"
    }
}
