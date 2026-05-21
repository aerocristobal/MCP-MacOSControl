# STORY-024 — Audit Log Integrity, Retention, and Off-Host Shipping

**Epic:** EPIC-7 · Production Hardening
**Priority:** 🔴 Critical
**Story Points:** 3
**Sprint Target:** Sprint 6 (Hardening)
**Dependencies:** None (extends existing `AuditRecorder.swift` from STORY-006)
**Refinement Round:** 8 — Newly added during Round 8 audit. Hardens the compensating control that SECURITY.md §4.1 describes as the primary mitigation for accepted AppleScript filter bypass risk.

---

## 1. User Story Narrative

```
Story: Audit Log Integrity, Retention, and Off-Host Shipping
In order to make the audit trail trustworthy as a compensating control in regulated environments
As a security reviewer or incident responder investigating a potential AppleScript filter bypass
I want the audit log to be tamper-evident, retained for a documented period, and shipped off-host to a managed log destination
So that the SECURITY.md §4.1 claim that "detection compensates for imperfect prevention" is operationally true rather than aspirational
```

**Additional Context:** STORY-006 shipped `AuditRecorder.swift` (visible in `Sources/MacOSControlLib/AppleScript/`) per Round 4 DoD. The current implementation records invocation events but offers none of the three properties expected of a regulated-environment audit log: (a) tamper-evidence — a determined adversary with write access to the host can edit prior records; (b) retention — no documented policy on how long records are kept; (c) off-host shipping — records live on the host where the server runs, the worst place to store evidence about that host. This story closes all three gaps. It is the highest-leverage Epic-2 hardening item because SECURITY.md §4.1 explicitly treats the audit hook as the primary compensating control for the AppleScript filter's documented bypass classes.

---

## 2. Acceptance Criteria (BDD Scenarios)

```gherkin
@epic-7 @story-024 @security @audit-log
Feature: Audit Log Integrity, Retention, and Off-Host Shipping
  In order to make the audit trail trustworthy as a compensating control
  As a security reviewer
  I want tamper-evident, retained, off-host-shipped audit logs

  Background:
    Given AuditRecorder is integrated into AppleScriptExecutor per STORY-006
    And the audit log destination is configured

  # --- Tamper evidence ---

  Scenario: Each audit record includes the hash of the prior record
    Given the audit log contains records R1, R2, R3 written in that order
    When the records are inspected
    Then R2.prev_hash equals SHA-256(R1)
    And R3.prev_hash equals SHA-256(R2)
    And R1.prev_hash equals the genesis constant defined in AuditRecorder

  Scenario: Tampering with a prior record breaks the chain at the next record
    Given an attacker modifies R2 in place to change the recorded script SHA-256
    When the audit chain verifier runs
    Then verification fails at R3 because R3.prev_hash no longer matches SHA-256(modified R2)
    And the verifier reports the first break point and the affected record range

  Scenario: New audit records are append-only — no record is ever modified after write
    Given the AuditRecorder is in operation
    When any code path attempts to rewrite a previously persisted record
    Then a structured error with error_code "audit_log_immutability_violation" is raised
    And the original record on disk is unchanged

  # --- Retention ---

  Scenario: Audit records are retained for the configured retention window
    Given the retention policy is configured to 365 days
    When the retention sweep runs
    Then records older than 365 days are moved to the archival destination
    And records within 365 days remain in the active log
    And no record is deleted before being acknowledged by the archival destination

  Scenario: Records moved to archive remain chain-verifiable
    Given records R1..R100 exist
    And records R1..R50 have been moved to archive
    When the chain verifier runs across the combined active + archive set
    Then the chain is unbroken from R1 to R100

  # --- Off-host shipping ---

  Scenario: Each audit record is shipped to the configured remote destination within the SLA window
    Given the remote destination is configured (OSLog with Console.app, syslog, or HTTP JSON sink)
    When AuditRecorder writes a record
    Then within 5 seconds the record is acknowledged by the remote destination
    And the local record is annotated with the remote acknowledgment timestamp

  Scenario: Remote destination outage does not lose records
    Given the remote destination is unreachable
    When AuditRecorder writes records during the outage
    Then records continue to be written to the local log with delivery_status "pending"
    And when the destination recovers, pending records are flushed in order
    And each flushed record is annotated with its acknowledgment timestamp

  # --- Configuration ---

  Scenario: Retention and remote destination are configurable via env vars
    Given environment variable MCP_MACOS_CONTROL_AUDIT_RETENTION_DAYS = 90
    And environment variable MCP_MACOS_CONTROL_AUDIT_REMOTE = "oslog"
    When the server starts
    Then the audit retention window is set to 90 days
    And the remote shipping destination is OSLog

  Scenario: Server refuses to start when audit config is internally inconsistent
    Given MCP_MACOS_CONTROL_AUDIT_REMOTE = "http"
    But MCP_MACOS_CONTROL_AUDIT_REMOTE_URL is unset
    When the server starts
    Then startup fails with error_code "audit_config_invalid"
    And the error message names the missing variable

  Scenario Outline: Audit record schema includes mandatory fields
    Given an AuditRecord is written
    When the record's serialized JSON is inspected
    Then it includes the field <field>
    And the field has type <type>

    Examples:
      | field                  | type              |
      | record_id              | uuid_string       |
      | timestamp_iso8601      | string            |
      | event_type             | enum_string       |
      | script_sha256          | hex_string        |
      | target_apps_extracted  | string_array      |
      | filter_disposition     | enum_string       |
      | execution_outcome      | enum_string       |
      | prev_hash              | hex_string        |
      | record_hash            | hex_string        |
      | delivery_status        | enum_string       |
      | remote_ack_timestamp   | nullable_string   |
      | host_identifier        | string            |
      | server_version         | string            |
```

---

## 3. Scenario Coverage Checklist

| Coverage Type | Scenario(s) | Status |
|---|---|---|
| Main success path | Hash chain written; retention window honored; off-host ack received | ✅ |
| Alternative success path | Records moved to archive remain chain-verifiable; remote outage recovery flushes in order | ✅ |
| Boundary condition | Genesis hash on R1; remote-ack SLA of 5 seconds; outline covers full mandatory field set | ✅ |
| Error / rejection path | Tampering breaks chain; rewrite attempt raises error; misconfiguration prevents startup | ✅ |
| Business rule edge case | Append-only enforcement at code level (not just at filesystem level) | ✅ |

---

## 4. Three Amigos Open Questions

| # | Question | Resolution |
|---|---|---|
| Q1 | Default retention period? | **365 days.** Long enough for incident-response cycles; short enough that on-host storage doesn't grow unbounded. Configurable downward via env var; upward only with archival destination configured. _[NEEDS CONFIRMATION]_ |
| Q2 | Default remote destination? | **OSLog (subsystem `com.mcp.macos-control.audit`).** Built into macOS; auditable via `log show` and Console.app; no external dependency. HTTP JSON sink is opt-in for managed log collectors (Splunk, Datadog, custom SIEM). _[NEEDS CONFIRMATION]_ |
| Q3 | What if the remote ack never arrives — does the local record get rotated out? | **No. Records with delivery_status: pending never get rotated.** Rotation requires either delivery_status: acknowledged or operator action via a documented "force_rotate_unacked" command. Prevents silent log loss during a sustained outage. _[NEEDS CONFIRMATION]_ |
| Q4 | How is the genesis hash determined per-install? | **Deterministic: `SHA-256("mcp-macos-control-audit-genesis|" + host_identifier + "|" + server_install_uuid)`.** Per-install genesis prevents cross-install confusion; deterministic prevents tampering with the genesis itself. |
| Q5 | What's the chain-verification frequency? | **On every server start (catches in-place modifications during shutdown); on every retention sweep (catches mid-life tampering); on operator-requested via a new `verify_audit_chain` admin tool.** _[NEEDS CONFIRMATION]_ |
| Q6 | Where do verification failures get reported? | **Structured error to the configured remote destination AND a critical OSLog message AND a SECURITY-CRITICAL log line at server start.** Verification failures are themselves auditable events. |
| Q7 | Should records include the script SOURCE in addition to its SHA-256? | **No — by design. SECURITY.md §4.2 (exfiltration via stdout) treats script source as sensitive.** Recording the source in the audit log would inadvertently archive every secret the agent has typed via AppleScript. SHA-256 + statically-extracted target apps is the right balance. |
| Q8 | What format on disk — JSON Lines, append-only binary, SQLite? | **JSON Lines (`audit-YYYY-MM-DD.jsonl`).** Append-friendly, parseable by every log tool, debuggable by humans. File rotation at midnight UTC. _[NEEDS CONFIRMATION]_ |

---

## 5. TDD Implementation Map

| BDD Scenario | Step | Step Type | Unit Under Test | TDD Test Cases Required |
|---|---|---|---|---|
| Hash chain present | When records written | When | `AuditRecorder.write(_:)` | test_writeRecord_setsPrevHashToPriorRecordSha256, test_firstRecord_setsPrevHashToGenesis |
| Tampering detected | Given modified record | Given | `AuditChainVerifier.verify(_:)` | test_verify_detectsTampering_atFirstBreak, test_verify_returnsBreakPointAndAffectedRange |
| Append-only enforcement | When rewrite attempted | When | `AuditRecorder.append(_:)` | test_append_throwsImmutabilityViolation_whenRecordExists |
| Retention window honored | When sweep runs | When | `AuditRetentionSweeper.sweep()` | test_sweep_movesOldRecordsToArchive, test_sweep_keepsRecentRecords, test_sweep_doesNotDeleteUnacknowledgedRecords |
| Archive chain unbroken | After sweep | Then | `AuditChainVerifier.verifyAcrossSets(_:)` | test_verifyAcrossSets_succeeds_whenChainSpansActiveAndArchive |
| Remote ack within SLA | When record written | When | `AuditRemoteSink.ship(_:timeout:)` | test_ship_returnsAckTimestamp_within5Seconds, test_ship_returnsTimeoutAfter5Seconds |
| Outage recovery | When destination recovers | When | `AuditRemoteSink` retry loop | test_retry_flushesPendingRecordsInOrder, test_retry_annotatesAckTimestampOnEachFlushed |
| Config-driven retention | Given env var set | Given | `AuditConfig.load(env:)` | test_load_setsRetentionDaysFromEnv, test_load_setsRemoteFromEnv |
| Invalid config rejected | Given inconsistent env | Given | `AuditConfig.validate()` | test_validate_throwsConfigInvalid_whenHttpWithoutUrl |
| Mandatory fields | Each field present | Then | `AuditRecord` Codable | test_record_serialization_includesEveryMandatoryField |

---

## 6. TDD Unit Test Scaffolds

```swift
// FILE: Tests/MCP-MacOSControlTests/AppleScript/AuditChainTests.swift
// STORY: STORY-024 — Audit Log Integrity, Retention, and Off-Host Shipping
// COMPONENT: AuditRecorder + AuditChainVerifier (hash chain integrity)

import XCTest
import CryptoKit
@testable import MacOSControlLib

final class AuditChainTests: XCTestCase {

    var recorder: AuditRecorder!
    var fakeRemoteSink: FakeAuditRemoteSink!
    var fakeStorage: FakeAuditStorage!

    override func setUp() {
        super.setUp()
        fakeStorage = FakeAuditStorage()
        fakeRemoteSink = FakeAuditRemoteSink()
        recorder = AuditRecorder(storage: fakeStorage, remoteSink: fakeRemoteSink,
                                 genesisInputs: ("test-host", "install-uuid-12345"))
    }

    // MARK: - Hash Chain

    func test_writeRecord_setsPrevHashToPriorRecordSha256() throws {
        let r1 = try recorder.write(makeRecord(eventType: .execute, scriptSha: "abc"))
        let r2 = try recorder.write(makeRecord(eventType: .execute, scriptSha: "def"))
        XCTAssertEqual(r2.prev_hash, sha256(of: r1))
    }

    func test_firstRecord_setsPrevHashToGenesisDerivedFromHostAndInstall() throws {
        let r1 = try recorder.write(makeRecord(eventType: .execute, scriptSha: "abc"))
        let expectedGenesis = sha256(of: "mcp-macos-control-audit-genesis|test-host|install-uuid-12345")
        XCTAssertEqual(r1.prev_hash, expectedGenesis)
    }

    // MARK: - Tamper Detection

    func test_verify_detectsTampering_atFirstBreak() throws {
        let r1 = try recorder.write(makeRecord(scriptSha: "a"))
        let r2 = try recorder.write(makeRecord(scriptSha: "b"))
        let r3 = try recorder.write(makeRecord(scriptSha: "c"))
        // Attacker rewrites R2 in storage
        fakeStorage.mutate(r2.record_id) { rec in
            var modified = rec
            modified.script_sha256 = "tampered"
            return modified
        }
        let verifier = AuditChainVerifier(storage: fakeStorage,
                                          genesisInputs: ("test-host", "install-uuid-12345"))
        let report = try verifier.verify()
        XCTAssertFalse(report.isValid)
        XCTAssertEqual(report.firstBreakAt, r3.record_id)
        XCTAssertEqual(report.affectedRange?.lowerBound, r3.record_id)
    }

    func test_verify_succeeds_onUntamperedChain() throws {
        _ = try recorder.write(makeRecord(scriptSha: "a"))
        _ = try recorder.write(makeRecord(scriptSha: "b"))
        let verifier = AuditChainVerifier(storage: fakeStorage,
                                          genesisInputs: ("test-host", "install-uuid-12345"))
        let report = try verifier.verify()
        XCTAssertTrue(report.isValid)
        XCTAssertNil(report.firstBreakAt)
    }

    // MARK: - Append-Only

    func test_append_throwsImmutabilityViolation_whenSameRecordIdWrittenTwice() throws {
        let r1 = try recorder.write(makeRecord(scriptSha: "a"))
        XCTAssertThrowsError(try recorder.append(r1)) { error in
            XCTAssertTrue(error is AuditLogImmutabilityViolation)
        }
    }

    // MARK: - Remote Shipping

    func test_write_shipsRecordToRemote() async throws {
        _ = try recorder.write(makeRecord(scriptSha: "a"))
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(fakeRemoteSink.shippedRecords.count, 1)
    }

    func test_write_returnsAckTimestamp_within5Seconds() async throws {
        fakeRemoteSink.ackDelayMs = 50
        let r = try recorder.write(makeRecord(scriptSha: "a"))
        try await Task.sleep(nanoseconds: 200_000_000)
        let stored = fakeStorage.read(r.record_id)
        XCTAssertNotNil(stored?.remote_ack_timestamp)
    }

    func test_write_timesOutAfter5Seconds_andMarksPending() async throws {
        fakeRemoteSink.ackDelayMs = 6000
        let r = try recorder.write(makeRecord(scriptSha: "a"))
        try await Task.sleep(nanoseconds: 5_500_000_000)
        let stored = fakeStorage.read(r.record_id)
        XCTAssertEqual(stored?.delivery_status, .pending)
        XCTAssertNil(stored?.remote_ack_timestamp)
    }

    // MARK: - Mandatory Fields

    func test_record_serialization_includesEveryMandatoryField() throws {
        let r = try recorder.write(makeRecord(scriptSha: "a"))
        let encoded = try JSONEncoder().encode(r)
        let json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        for field in ["record_id", "timestamp_iso8601", "event_type", "script_sha256",
                      "target_apps_extracted", "filter_disposition", "execution_outcome",
                      "prev_hash", "record_hash", "delivery_status", "host_identifier",
                      "server_version"] {
            XCTAssertNotNil(json[field], "Missing mandatory field: \(field)")
        }
    }
}
```

```swift
// FILE: Tests/MCP-MacOSControlTests/AppleScript/AuditRetentionTests.swift

final class AuditRetentionTests: XCTestCase {

    var sweeper: AuditRetentionSweeper!
    var fakeStorage: FakeAuditStorage!
    var fakeArchive: FakeAuditArchive!
    var fakeClock: FakeClock!

    override func setUp() {
        super.setUp()
        fakeStorage = FakeAuditStorage()
        fakeArchive = FakeAuditArchive()
        fakeClock = FakeClock(now: Date(timeIntervalSince1970: 1_716_000_000))
        sweeper = AuditRetentionSweeper(
            storage: fakeStorage, archive: fakeArchive, clock: fakeClock,
            retentionDays: 365)
    }

    func test_sweep_movesOldRecordsToArchive() throws {
        let oldDate = fakeClock.now.addingTimeInterval(-400 * 86_400)
        let newDate = fakeClock.now.addingTimeInterval(-30 * 86_400)
        fakeStorage.insert(makeRecord(timestamp: oldDate))
        fakeStorage.insert(makeRecord(timestamp: newDate))
        try sweeper.sweep()
        XCTAssertEqual(fakeArchive.records.count, 1)
        XCTAssertEqual(fakeStorage.allRecords.count, 1)
    }

    func test_sweep_doesNotDeleteUnacknowledgedRecords() throws {
        let oldDate = fakeClock.now.addingTimeInterval(-400 * 86_400)
        fakeStorage.insert(makeRecord(timestamp: oldDate, deliveryStatus: .pending))
        try sweeper.sweep()
        XCTAssertEqual(fakeStorage.allRecords.count, 1, "Pending records must not rotate")
        XCTAssertEqual(fakeArchive.records.count, 0)
    }
}
```

---

## 7. Dependencies & Test Doubles

| Dependency | Type | Source | Notes |
|---|---|---|---|
| Existing `AuditRecorder` | Extended (not replaced) | `FakeAuditStorage` | Round 4 baseline; this story extends with hash chain + remote sink + retention |
| `CryptoKit` for SHA-256 | Apple framework | No double | Used for record_hash and prev_hash |
| `OSLog` | Apple framework | `FakeAuditRemoteSink` | Default remote sink; subsystem `com.mcp.macos-control.audit` |
| `URLSession` for HTTP sink | Apple framework | `FakeAuditRemoteSink` | Opt-in via env var |
| `Clock` abstraction | Existing | `FakeClock` | Deterministic retention tests |
| `ErrorCodeRegistry` (STORY-016) | Real | No double | Registers `audit_log_immutability_violation`, `audit_config_invalid`, `audit_chain_verification_failed` |

---

## 8. Definition of Done

**Hash chain**
- [ ] Every `AuditRecord` includes `prev_hash` (SHA-256 of prior record's `record_hash`) and `record_hash` (SHA-256 of the record's canonical JSON minus `record_hash`)
- [ ] Genesis hash deterministically derived from host_identifier + install_uuid
- [ ] `AuditChainVerifier` produces a structured report (`isValid`, `firstBreakAt`, `affectedRange`)
- [ ] Chain verification runs on server start, on every retention sweep, and on operator request

**Retention**
- [ ] `AuditRetentionSweeper` runs daily; configurable via `MCP_MACOS_CONTROL_AUDIT_RETENTION_DAYS` (default 365)
- [ ] Records moved to archive remain chain-verifiable (archive participates in chain)
- [ ] Records with `delivery_status: pending` are never rotated regardless of age
- [ ] Operator-initiated `force_rotate_unacked` admin command supported (with explicit warning)

**Off-host shipping**
- [ ] Default sink: OSLog subsystem `com.mcp.macos-control.audit`
- [ ] Optional HTTP JSON sink configured via `MCP_MACOS_CONTROL_AUDIT_REMOTE=http` + `..._REMOTE_URL`
- [ ] Optional syslog sink configured via `MCP_MACOS_CONTROL_AUDIT_REMOTE=syslog`
- [ ] Each record's `remote_ack_timestamp` populated within 5 seconds of write or marked pending
- [ ] Retry loop flushes pending records in order on destination recovery

**Configuration**
- [ ] All audit-related env vars documented in `README.md` "Environment Variables" section
- [ ] Server refuses to start when audit config is internally inconsistent
- [ ] Invalid config produces `audit_config_invalid` structured error per STORY-016

**Schema**
- [ ] `AuditRecord` includes all 13 mandatory fields per the BDD outline
- [ ] JSON Lines on-disk format (`audit-YYYY-MM-DD.jsonl`); midnight UTC rotation
- [ ] Schema versioned (`audit_schema_version: 1`) for future evolution

**Tests**
- [ ] All BDD scenarios pass in CI
- [ ] Unit coverage ≥ 90% on `AuditRecorder`, `AuditChainVerifier`, `AuditRetentionSweeper`, `AuditRemoteSink`
- [ ] Property-based test: 1000 random write sequences produce chain-verifiable logs
- [ ] Integration test in `Tests/MCP-MacOSControlIntegrationTests/Security/AuditLogIntegrityTests.swift` verifies the full path against real OSLog

**Documentation & compliance**
- [ ] `docs/SECURITY.md` §4.1 updated: "The audit hook compensates for imperfect prevention" — now backed by hash chain, retention, and off-host shipping
- [ ] `docs/SECURITY.md` §7 updated: AU-2, AU-3 implementation statements reference the new integrity properties
- [ ] STORY-022 OSCAL component definition updated to reference the new properties under AU-2 / AU-3
- [ ] `docs/stories/STORY-024-audit-log-integrity.md` (this file) committed
- [ ] `docs/AUDIT-LOG-OPERATIONS.md` written for operators: log location, rotation policy, verification commands, incident-response playbook

---

## 9. Notes & Observations

- **Why a hash chain rather than just signing each record?** A per-record signature requires key management. A hash chain only requires a tamper-evident storage medium and a verification routine; the host_identifier + install_uuid serves as a per-install root that an attacker would have to also rewrite. Signing is a stronger property but adds a key-management surface to the project. Reassess if the threat model evolves to include adversaries with both write and key-extraction capability.
- **Why doesn't the script source appear in the audit record?** SECURITY.md §4.2 treats stdout exfiltration as a real threat. Scripts can contain typed passwords, API keys, and personal data. Recording the source would turn the audit log into a sensitive-data archive — the opposite of its purpose. SHA-256 + statically-extracted target apps is enough for forensics (the original tool call payload remains in the MCP host's own logs, if it kept them).
- **Why does OSLog get default treatment over HTTP / syslog?** OSLog is built in, requires no external service, integrates with Console.app for ad-hoc review, and is collected by enterprise MDM tooling on macOS. HTTP sink exists for managed-SIEM environments that need centralized aggregation; syslog exists for deployers with legacy infrastructure. Three options cover the realistic deployment surface.
- **Why is "pending records never rotate" the rule?** Silent log loss during a destination outage is the worst possible audit failure mode. Operators noticing "my archive has fewer records than my active log" is a clear signal; archives that quietly drop pending records during outages remove that signal. Operator-initiated `force_rotate_unacked` exists for the case where the operator has accepted the loss; it logs its own action prominently.
- **Relationship to STORY-022 (OSCAL):** This story makes AU-2 and AU-3 implementation statements truthful. Without STORY-024, those statements describe an existing recorder that lacks the properties typical AU-2/AU-3 implementations assert.
- **Relationship to STORY-025 (filter fuzz, follow-up):** Fuzz testing the filter produces bypass attempts. Every bypass attempt produces an audit record. The integrity properties this story ships ensure those audit records are themselves trustworthy.
