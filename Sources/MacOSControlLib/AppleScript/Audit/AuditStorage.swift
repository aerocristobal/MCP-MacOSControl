// STORY-024 — Persistent audit storage.
//
// Design:
//   * Records and acks are written to *separate* append-only JSON
//     Lines files so the immutable record stream's hash chain is
//     never disturbed by delivery-status updates.
//
//       audit-YYYY-MM-DD.jsonl   <- one line per AuditRecord, written ONCE
//       ack-YYYY-MM-DD.jsonl     <- one line per AckEntry, may have multiple
//                                   entries per record (e.g. retry succeeded)
//
//   * Archive/ subdir holds older files moved by AuditRetentionSweeper.
//
//   * `allRecords()` reads every file in lexicographic order, merging
//     the latest ack for each record into the returned AuditRecord's
//     deliveryStatus / remoteAckTimestamp fields. This gives callers a
//     consistent merged view without ever rewriting an audit file.
//
// Why JSON Lines? Append-friendly, line-oriented (so a single half-
// written line can be detected and skipped without losing the rest of
// the file), parseable by every log tool, and human-readable. The
// story's Q8 answer is JSONL.

import Foundation

/// Single ack/delivery-status update appended to the ack ledger.
public struct AuditAckEntry: Codable, Equatable, Sendable {
    public let recordId: UUID
    public let deliveryStatus: AuditDeliveryStatus
    public let remoteAckTimestamp: String?   // nil when delivery_status=failed
    public let appendedAt: String            // iso8601 of when the ack landed locally

    public init(
        recordId: UUID,
        deliveryStatus: AuditDeliveryStatus,
        remoteAckTimestamp: String?,
        appendedAt: String
    ) {
        self.recordId = recordId
        self.deliveryStatus = deliveryStatus
        self.remoteAckTimestamp = remoteAckTimestamp
        self.appendedAt = appendedAt
    }

    enum CodingKeys: String, CodingKey {
        case recordId = "record_id"
        case deliveryStatus = "delivery_status"
        case remoteAckTimestamp = "remote_ack_timestamp"
        case appendedAt = "appended_at"
    }
}

/// Storage protocol. Concrete impls: FileAuditStorage (production),
/// InMemoryAuditStorage / FakeAuditStorage (tests).
public protocol AuditStorage: AnyObject, Sendable {

    /// Append a record. Throws AuditLogImmutabilityViolation if
    /// `record.recordId` is already present.
    func insert(_ record: AuditRecord) throws

    /// Append an ack. Multiple acks per record are allowed (retry
    /// loop); the latest ack wins when records are read back.
    func appendAck(_ entry: AuditAckEntry) throws

    /// Look up a record by id, returning the merged view (latest ack
    /// folded into deliveryStatus / remoteAckTimestamp). Nil if absent.
    func read(_ recordId: UUID) -> AuditRecord?

    /// All records (active + archive) in append order, merged with
    /// their latest acks.
    func allRecords() -> [AuditRecord]

    /// Active-only records (not yet archived).
    func activeRecords() -> [AuditRecord]

    /// Archive-only records.
    func archivedRecords() -> [AuditRecord]

    /// Move records out of the active log into archive. Sweeper calls
    /// this with the subset of records older than retentionDays AND
    /// acknowledged. After this returns, the moved records appear in
    /// archivedRecords() and disappear from activeRecords(); allRecords()
    /// is the union, unchanged.
    func moveToArchive(_ records: [AuditRecord]) throws
}

/// Production storage: JSON Lines on disk, daily-named files,
/// append-only via FileHandle seek-to-end. Thread-safe via a dispatch
/// queue.
public final class FileAuditStorage: AuditStorage, @unchecked Sendable {

    private let activeDir: URL
    private let archiveDir: URL
    private let clock: Clock
    private let fm: FileManager

    private let queue = DispatchQueue(label: "com.macoscontrol.audit.storage", qos: .utility)

    // In-memory index of record_id -> file-relative location.
    // Used for O(1) duplicate detection on insert and O(1) lookup on
    // read. Populated lazily from disk on first access.
    private struct Location: Equatable {
        let filename: String
        let isArchive: Bool
    }
    private var index: [UUID: Location] = [:]
    private var indexLoaded = false

    public init(
        logDirectory: URL,
        clock: Clock = SystemClock(),
        fileManager: FileManager = .default
    ) throws {
        self.activeDir = logDirectory
        self.archiveDir = logDirectory.appendingPathComponent("archive", isDirectory: true)
        self.clock = clock
        self.fm = fileManager
        try fm.createDirectory(at: activeDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: archiveDir, withIntermediateDirectories: true)
    }

    public func insert(_ record: AuditRecord) throws {
        try queue.sync {
            try ensureIndexLoaded()
            if let _ = index[record.recordId] {
                throw AuditLogImmutabilityViolation(recordId: record.recordId)
            }
            let filename = currentRecordsFilename()
            let url = activeDir.appendingPathComponent(filename)
            try appendLine(try encode(record), to: url)
            index[record.recordId] = Location(filename: filename, isArchive: false)
        }
    }

    public func appendAck(_ entry: AuditAckEntry) throws {
        try queue.sync {
            let filename = currentAcksFilename(for: entry)
            let url = activeDir.appendingPathComponent(filename)
            try appendLine(try encode(entry), to: url)
        }
    }

    public func read(_ recordId: UUID) -> AuditRecord? {
        queue.sync {
            try? ensureIndexLoaded()
            guard let loc = index[recordId] else { return nil }
            let url = (loc.isArchive ? archiveDir : activeDir).appendingPathComponent(loc.filename)
            guard let recs = try? readRecords(from: url) else { return nil }
            guard let raw = recs.first(where: { $0.recordId == recordId }) else { return nil }
            let acks = readAllAcks()
            return mergeAck(into: raw, from: acks)
        }
    }

    public func allRecords() -> [AuditRecord] {
        queue.sync {
            try? ensureIndexLoaded()
            let archived = listFiles(in: archiveDir, prefix: "audit-")
            let active = listFiles(in: activeDir, prefix: "audit-")
            let recs = (archived + active).flatMap { (try? readRecords(from: $0)) ?? [] }
            let acks = readAllAcks()
            return recs.map { mergeAck(into: $0, from: acks) }
        }
    }

    public func activeRecords() -> [AuditRecord] {
        queue.sync {
            try? ensureIndexLoaded()
            let active = listFiles(in: activeDir, prefix: "audit-")
            let recs = active.flatMap { (try? readRecords(from: $0)) ?? [] }
            let acks = readAllAcks()
            return recs.map { mergeAck(into: $0, from: acks) }
        }
    }

    public func archivedRecords() -> [AuditRecord] {
        queue.sync {
            try? ensureIndexLoaded()
            let archived = listFiles(in: archiveDir, prefix: "audit-")
            let recs = archived.flatMap { (try? readRecords(from: $0)) ?? [] }
            let acks = readAllAcks()
            return recs.map { mergeAck(into: $0, from: acks) }
        }
    }

    public func moveToArchive(_ records: [AuditRecord]) throws {
        try queue.sync {
            try ensureIndexLoaded()
            guard !records.isEmpty else { return }

            // Group records by their active filename so we only rewrite each
            // file once.
            var byFile: [String: [AuditRecord]] = [:]
            for r in records {
                guard let loc = index[r.recordId], !loc.isArchive else { continue }
                byFile[loc.filename, default: []].append(r)
            }
            let movedIds = Set(records.map { $0.recordId })

            for (filename, _) in byFile {
                let activeUrl = activeDir.appendingPathComponent(filename)
                let archiveUrl = archiveDir.appendingPathComponent(filename)

                let existingActive = (try? readRecords(from: activeUrl)) ?? []
                let toMove = existingActive.filter { movedIds.contains($0.recordId) }
                let toKeep = existingActive.filter { !movedIds.contains($0.recordId) }

                // Append the moved records to the archive file (preserving order).
                let existingArchive = (try? readRecords(from: archiveUrl)) ?? []
                let merged = existingArchive + toMove
                try writeRecords(merged, to: archiveUrl)

                // Rewrite the active file with only the kept records.
                // This is the one place in the codebase where we replace
                // an audit file's contents — it's an authorized archival
                // operation, not a record modification, and we never
                // change the record content itself.
                if toKeep.isEmpty {
                    try? fm.removeItem(at: activeUrl)
                } else {
                    try writeRecords(toKeep, to: activeUrl)
                }

                // Update the in-memory index for the moved records.
                for r in toMove {
                    index[r.recordId] = Location(filename: filename, isArchive: true)
                }
            }
        }
    }

    // MARK: - Filename + path helpers

    private func currentRecordsFilename() -> String {
        "audit-\(Self.dayStamp(clock.now())).jsonl"
    }

    private func currentAcksFilename(for entry: AuditAckEntry) -> String {
        // Acks land in a file named for the day the ack was emitted —
        // not the day the record was emitted — so the ack-ledger files
        // line up with operational events.
        let day: String = {
            if let d = AuditTimestamp.parse(entry.appendedAt) {
                return Self.dayStamp(d)
            }
            return Self.dayStamp(clock.now())
        }()
        return "ack-\(day).jsonl"
    }

    static func dayStamp(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - I/O primitives

    private func appendLine(_ data: Data, to url: URL) throws {
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        var payload = data
        payload.append(0x0A)  // newline
        try handle.write(contentsOf: payload)
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try enc.encode(value)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    private func readRecords(from url: URL) throws -> [AuditRecord] {
        guard fm.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        guard let s = String(data: data, encoding: .utf8) else { return [] }
        var result: [AuditRecord] = []
        for line in s.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let bytes = line.data(using: .utf8) else { continue }
            if let rec = try? decode(AuditRecord.self, from: bytes) {
                result.append(rec)
            }
        }
        return result
    }

    private func writeRecords(_ records: [AuditRecord], to url: URL) throws {
        var bytes = Data()
        for r in records {
            var line = try encode(r)
            line.append(0x0A)
            bytes.append(line)
        }
        try bytes.write(to: url, options: .atomic)
    }

    private func readAcks(from url: URL) throws -> [AuditAckEntry] {
        guard fm.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        guard let s = String(data: data, encoding: .utf8) else { return [] }
        var result: [AuditAckEntry] = []
        for line in s.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let bytes = line.data(using: .utf8) else { continue }
            if let ack = try? decode(AuditAckEntry.self, from: bytes) {
                result.append(ack)
            }
        }
        return result
    }

    private func readAllAcks() -> [UUID: AuditAckEntry] {
        // Latest-wins merge across all ack files. The "latest" is
        // ordered by appended_at; ties resolve by acknowledged > failed
        // > pending so a successful late ack supersedes a prior pending.
        var latest: [UUID: AuditAckEntry] = [:]
        let files = listFiles(in: activeDir, prefix: "ack-") + listFiles(in: archiveDir, prefix: "ack-")
        for url in files {
            for ack in (try? readAcks(from: url)) ?? [] {
                if let existing = latest[ack.recordId] {
                    if shouldPreferAck(ack, over: existing) {
                        latest[ack.recordId] = ack
                    }
                } else {
                    latest[ack.recordId] = ack
                }
            }
        }
        return latest
    }

    private func shouldPreferAck(_ new: AuditAckEntry, over old: AuditAckEntry) -> Bool {
        // Acknowledged supersedes anything else; otherwise the later
        // appended_at wins.
        if new.deliveryStatus == .acknowledged && old.deliveryStatus != .acknowledged { return true }
        if old.deliveryStatus == .acknowledged && new.deliveryStatus != .acknowledged { return false }
        return new.appendedAt >= old.appendedAt
    }

    private func mergeAck(
        into record: AuditRecord,
        from acks: [UUID: AuditAckEntry]
    ) -> AuditRecord {
        guard let ack = acks[record.recordId] else { return record }
        return record.annotated(
            deliveryStatus: ack.deliveryStatus,
            remoteAckTimestamp: ack.remoteAckTimestamp
        )
    }

    private func listFiles(in directory: URL, prefix: String) -> [URL] {
        guard let names = try? fm.contentsOfDirectory(atPath: directory.path) else { return [] }
        return names
            .filter { $0.hasPrefix(prefix) && $0.hasSuffix(".jsonl") }
            .sorted()
            .map { directory.appendingPathComponent($0) }
    }

    private func ensureIndexLoaded() throws {
        guard !indexLoaded else { return }
        indexLoaded = true
        for url in listFiles(in: archiveDir, prefix: "audit-") {
            let filename = url.lastPathComponent
            for rec in (try? readRecords(from: url)) ?? [] {
                index[rec.recordId] = Location(filename: filename, isArchive: true)
            }
        }
        for url in listFiles(in: activeDir, prefix: "audit-") {
            let filename = url.lastPathComponent
            for rec in (try? readRecords(from: url)) ?? [] {
                index[rec.recordId] = Location(filename: filename, isArchive: false)
            }
        }
    }
}

/// Process-local, in-memory storage. Used by AppleScriptModule when
/// audit configuration explicitly opts out of persistence, and as the
/// base class for FakeAuditStorage in tests.
public class InMemoryAuditStorage: AuditStorage, @unchecked Sendable {

    private let queue = DispatchQueue(label: "com.macoscontrol.audit.in-memory-storage")
    private var active: [AuditRecord] = []
    private var archived: [AuditRecord] = []
    private var acks: [UUID: AuditAckEntry] = [:]

    public init() {}

    public func insert(_ record: AuditRecord) throws {
        try queue.sync {
            if active.contains(where: { $0.recordId == record.recordId })
                || archived.contains(where: { $0.recordId == record.recordId }) {
                throw AuditLogImmutabilityViolation(recordId: record.recordId)
            }
            active.append(record)
        }
    }

    public func appendAck(_ entry: AuditAckEntry) throws {
        queue.sync {
            if let existing = acks[entry.recordId] {
                if existing.deliveryStatus == .acknowledged && entry.deliveryStatus != .acknowledged {
                    return
                }
            }
            acks[entry.recordId] = entry
        }
    }

    public func read(_ recordId: UUID) -> AuditRecord? {
        queue.sync {
            let all = active + archived
            guard let raw = all.first(where: { $0.recordId == recordId }) else { return nil }
            if let ack = acks[recordId] {
                return raw.annotated(deliveryStatus: ack.deliveryStatus,
                                     remoteAckTimestamp: ack.remoteAckTimestamp)
            }
            return raw
        }
    }

    public func allRecords() -> [AuditRecord] {
        queue.sync {
            (archived + active).map { rec in
                if let ack = acks[rec.recordId] {
                    return rec.annotated(deliveryStatus: ack.deliveryStatus,
                                         remoteAckTimestamp: ack.remoteAckTimestamp)
                }
                return rec
            }
        }
    }

    public func activeRecords() -> [AuditRecord] {
        queue.sync {
            active.map { rec in
                if let ack = acks[rec.recordId] {
                    return rec.annotated(deliveryStatus: ack.deliveryStatus,
                                         remoteAckTimestamp: ack.remoteAckTimestamp)
                }
                return rec
            }
        }
    }

    public func archivedRecords() -> [AuditRecord] {
        queue.sync {
            archived.map { rec in
                if let ack = acks[rec.recordId] {
                    return rec.annotated(deliveryStatus: ack.deliveryStatus,
                                         remoteAckTimestamp: ack.remoteAckTimestamp)
                }
                return rec
            }
        }
    }

    public func moveToArchive(_ records: [AuditRecord]) throws {
        queue.sync {
            let ids = Set(records.map { $0.recordId })
            let toMove = active.filter { ids.contains($0.recordId) }
            active.removeAll { ids.contains($0.recordId) }
            archived.append(contentsOf: toMove)
        }
    }
}
