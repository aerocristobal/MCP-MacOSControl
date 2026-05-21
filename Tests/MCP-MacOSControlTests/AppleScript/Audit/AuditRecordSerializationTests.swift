// STORY-024 — AuditRecord schema mandatory-field test.
//
// Mirrors the BDD Scenario Outline "Audit record schema includes
// mandatory fields" — every record must roundtrip JSON cleanly and
// expose every named field on serialization.

import XCTest
@testable import MacOSControlLib

final class AuditRecordSerializationTests: XCTestCase {

    func test_record_serialization_includesEveryMandatoryField() throws {
        let r = makeRecord()
        let encoded = try JSONEncoder().encode(r)
        let json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        for field in [
            "record_id",
            "timestamp_iso8601",
            "event_type",
            "script_sha256",
            "target_apps_extracted",
            "filter_disposition",
            "execution_outcome",
            "prev_hash",
            "record_hash",
            "delivery_status",
            "remote_ack_timestamp",
            "host_identifier",
            "server_version"
        ] {
            XCTAssertNotNil(json[field], "Missing mandatory field: \(field)")
        }
    }

    func test_record_roundtripsThroughJSONEncoder() throws {
        let r = makeRecord()
        let data = try JSONEncoder().encode(r)
        let r2 = try JSONDecoder().decode(AuditRecord.self, from: data)
        XCTAssertEqual(r, r2)
    }

    func test_canonicalJSONForHash_excludes_recordHash_and_deliveryAnnotations() throws {
        let r = makeRecord()
        let bytes = try r.canonicalJSONForHash()
        let s = String(data: bytes, encoding: .utf8) ?? ""
        XCTAssertFalse(s.contains("record_hash"),
                       "record_hash must not be hashed — would create self-reference")
        XCTAssertFalse(s.contains("delivery_status"),
                       "delivery_status mutates post-write — must be excluded from hash")
        XCTAssertFalse(s.contains("remote_ack_timestamp"),
                       "remote_ack_timestamp mutates post-write — must be excluded")
    }

    func test_canonicalJSONForHash_isStable_acrossInvocations() throws {
        let r = makeRecord()
        let a = try r.canonicalJSONForHash()
        let b = try r.canonicalJSONForHash()
        XCTAssertEqual(a, b, "Canonical JSON must be byte-stable to make record_hash reproducible")
    }

    func test_computeRecordHash_isReproducible() throws {
        let r = makeRecord()
        let h1 = try r.computeRecordHash()
        let h2 = try r.computeRecordHash()
        XCTAssertEqual(h1, h2)
        XCTAssertEqual(h1.count, 64, "SHA-256 hex is 64 chars")
    }

    func test_annotated_doesNotChangeRecordHash() throws {
        let r = makeRecord(deliveryStatus: .pending, remoteAck: nil)
        let h1 = try r.computeRecordHash()
        let r2 = r.annotated(deliveryStatus: .acknowledged,
                             remoteAckTimestamp: "2026-05-20T12:00:00.000Z")
        let h2 = try r2.computeRecordHash()
        XCTAssertEqual(h1, h2, "annotating ack must NOT change the chain hash")
    }

    func test_eventType_serializesAsSnakeCaseString() throws {
        let r = makeRecord(eventType: .administrativeForceRotateUnacked)
        let data = try JSONEncoder().encode(r)
        let s = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(s.contains("\"administrative_force_rotate_unacked\""))
    }

    // MARK: - Helpers

    private func makeRecord(
        eventType: AuditEventType = .applescriptExecute,
        deliveryStatus: AuditDeliveryStatus = .pending,
        remoteAck: String? = nil
    ) -> AuditRecord {
        AuditRecord(
            recordId: UUID(),
            timestampIso8601: "2026-05-20T12:00:00.000Z",
            eventType: eventType,
            scriptSha256: "abc123",
            targetAppsExtracted: ["Finder"],
            filterDisposition: .allowed,
            executionOutcome: .success,
            prevHash: String(repeating: "0", count: 64),
            recordHash: String(repeating: "f", count: 64),
            deliveryStatus: deliveryStatus,
            remoteAckTimestamp: remoteAck,
            hostIdentifier: "test-host",
            serverVersion: "1.0.0",
            durationMs: 42
        )
    }
}
