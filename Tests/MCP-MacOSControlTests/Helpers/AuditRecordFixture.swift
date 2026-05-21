// Test-only helper for constructing AuditRecord values from the
// STORY-024 schema. The compliance tests (STORY-037) and any future
// audit-stream tests use this rather than re-typing the 13 fields on
// every assertion.

import Foundation
@testable import MacOSControlLib

extension AuditRecord {

    /// Minimal AuditRecord with sensible defaults for compliance / OSCAL
    /// tests. Tests override only the fields that matter for the
    /// behavior they're asserting.
    static func fixture(
        recordId: UUID = UUID(),
        timestamp: Date = Date(timeIntervalSince1970: 1_747_000_000),
        eventType: AuditEventType = .applescriptExecute,
        scriptSha256: String = "deadbeef".padding(toLength: 64, withPad: "0", startingAt: 0),
        targetApps: [String] = ["TextEdit"],
        filterDisposition: AuditFilterDisposition = .allowed,
        executionOutcome: AuditExecutionOutcome = .success,
        prevHash: String = String(repeating: "0", count: 64),
        recordHash: String = String(repeating: "f", count: 64),
        deliveryStatus: AuditDeliveryStatus = .acknowledged,
        remoteAckTimestamp: String? = "2026-05-20T12:00:00.500Z",
        hostIdentifier: String = "test-host",
        serverVersion: String = "1.0.0",
        durationMs: Int = 12,
        rejectionReason: String? = nil,
        deniedApp: String? = nil,
        scriptErrorCode: Int? = nil
    ) -> AuditRecord {
        AuditRecord(
            recordId: recordId,
            timestampIso8601: AuditTimestamp.format(timestamp),
            eventType: eventType,
            scriptSha256: scriptSha256,
            targetAppsExtracted: targetApps,
            filterDisposition: filterDisposition,
            executionOutcome: executionOutcome,
            prevHash: prevHash,
            recordHash: recordHash,
            deliveryStatus: deliveryStatus,
            remoteAckTimestamp: remoteAckTimestamp,
            hostIdentifier: hostIdentifier,
            serverVersion: serverVersion,
            durationMs: durationMs,
            rejectionReason: rejectionReason,
            deniedApp: deniedApp,
            scriptErrorCode: scriptErrorCode
        )
    }
}
