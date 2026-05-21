// STORY-024 — Property test: 1000 random write sequences produce a
// chain-verifiable log.
//
// DoD: "Property-based test: 1000 random write sequences produce
// chain-verifiable logs." We don't pull in SwiftCheck — XCTest's
// built-in RNG with a fixed seed is enough for a reproducible
// property test.

import XCTest
import CryptoKit
@testable import MacOSControlLib

final class AuditChainPropertyTests: XCTestCase {

    func test_1000_random_writes_produce_a_verifiable_chain() throws {
        let storage = FakeAuditStorage()
        let sink = FakeAuditRemoteSink()
        let identity = AuditInstallIdentity(hostIdentifier: "prop-host",
                                            installUuid: "prop-uuid")
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
        let recorder = AuditRecorder(
            storage: storage,
            remoteSink: sink,
            config: config,
            identity: identity
        )

        // Seeded deterministic random source.
        var rng = SeededRNG(seed: 0xC0DE_AB1B)

        let outcomes: [AuditExecutionOutcome] = [
            .success, .scriptError, .timeout, .ioError, .notExecuted
        ]
        let dispositions: [AuditFilterDisposition] = [
            .allowed, .rejectedSecurity, .rejectedPermission
        ]
        let eventTypes: [AuditEventType] = [
            .applescriptExecute, .menuClick, .menuAlternativesLookup
        ]
        let sampleApps = ["Finder", "Safari", "Mail", "Notes", "Calendar"]

        for i in 0..<1000 {
            let draft = AuditRecordDraft(
                eventType: eventTypes.randomElement(using: &rng)!,
                scriptSha256: ScriptHasher.sha256Hex("iteration-\(i)"),
                targetApps: Array(sampleApps.shuffled(using: &rng).prefix(Int.random(in: 0...2, using: &rng))),
                filterDisposition: dispositions.randomElement(using: &rng)!,
                executionOutcome: outcomes.randomElement(using: &rng)!,
                durationMs: Int.random(in: 0...5_000, using: &rng),
                rejectionReason: Bool.random(using: &rng) ? "do_shell_script" : nil,
                deniedApp: Bool.random(using: &rng) ? "Mail" : nil,
                scriptErrorCode: Bool.random(using: &rng) ? Int.random(in: -3000 ... -1000, using: &rng) : nil
            )
            _ = recorder.record(draft)
        }

        let verifier = AuditChainVerifier(storage: storage, identity: identity)
        let report = verifier.verify()
        XCTAssertTrue(report.isValid, "chain broke: \(report.summary)")
        XCTAssertEqual(report.totalChecked, 1000)
    }
}

/// Deterministic 64-bit PRNG (xorshift*) so the property test is
/// reproducible. Avoids reliance on SystemRandomNumberGenerator which
/// can't be seeded.
private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state &* 0x2545_F491_4F6C_DD1D
    }
}
