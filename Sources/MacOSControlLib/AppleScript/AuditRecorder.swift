import Foundation
import CryptoKit

public struct AuditRecord: Equatable {
    public let timestamp: Date
    public let toolName: String
    public let scriptSha256: String
    public let scriptSource: String?
    public let outcome: AuditOutcome
    public let durationMs: Int
    public let targetApps: [String]

    public init(
        timestamp: Date,
        toolName: String,
        scriptSha256: String,
        scriptSource: String?,
        outcome: AuditOutcome,
        durationMs: Int,
        targetApps: [String]
    ) {
        self.timestamp = timestamp
        self.toolName = toolName
        self.scriptSha256 = scriptSha256
        self.scriptSource = scriptSource
        self.outcome = outcome
        self.durationMs = durationMs
        self.targetApps = targetApps
    }
}

public enum AuditOutcome: Equatable {
    case success
    case scriptError(code: Int)
    case timeout
    case securityRejected(reason: String)
    case permissionDenied(app: String)
}

public protocol AuditRecorder {
    func record(_ record: AuditRecord)
}

public final class InMemoryAuditRecorder: AuditRecorder {
    private let queue = DispatchQueue(label: "com.macoscontrol.audit.recorder")
    private var _records: [AuditRecord] = []

    public init() {}

    public var records: [AuditRecord] {
        queue.sync { _records }
    }

    public func record(_ record: AuditRecord) {
        queue.sync { _records.append(record) }
    }
}

public enum ScriptHasher {
    public static func sha256Hex(_ source: String) -> String {
        let digest = SHA256.hash(data: Data(source.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
