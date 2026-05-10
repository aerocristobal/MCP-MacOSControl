import Foundation
@testable import MacOSControlLib

final class AuditRecorderSpy: AuditRecorder {
    private(set) var records: [AuditRecord] = []

    func record(_ record: AuditRecord) {
        records.append(record)
    }
}
