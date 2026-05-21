// STORY-037 — oscal-emit CLI.
//
// Reads a JSONL stream of STORY-024 AuditRecords and appends one OSCAL
// Observation per record to oscal/assessment-results.json. Append-only:
// existing observations are never modified. Records that resolve to
// already-emitted observation UUIDs are dropped (deterministic UUIDs
// make this dedup possible).
//
// Usage:
//   oscal-emit <audit-records.jsonl> <assessment-results.json>
//   oscal-emit --retention-days 90 <records.jsonl> <ar.json>   (optional pruning)
//
// Exit codes:
//   0   on success
//   2   on usage error
//   3   on input file read error
//   4   on output file write error
//   5   on AuditRecord parse error (line skipped, exit at end of stream)

import Foundation
import MacOSControlLib
import OSCALComplianceSupport

struct OscalEmitOptions {
    var inputPath: String
    var outputPath: String
    var poamPath: String? = nil          // nil = don't update a POA&M
    var retentionDays: Int? = nil        // nil = no pruning
    var emitterVersion: String = "1.0.0"
}

func parseOptions(_ argv: [String]) -> OscalEmitOptions? {
    var positional: [String] = []
    var retentionDays: Int? = nil
    var poamPath: String? = nil

    var i = 1
    while i < argv.count {
        let arg = argv[i]
        if arg == "--retention-days" {
            i += 1
            if i >= argv.count { return nil }
            retentionDays = Int(argv[i])
            if retentionDays == nil { return nil }
        } else if arg == "--poam" {
            i += 1
            if i >= argv.count { return nil }
            poamPath = argv[i]
        } else if arg == "-h" || arg == "--help" {
            return nil
        } else {
            positional.append(arg)
        }
        i += 1
    }

    guard positional.count == 2 else { return nil }
    return OscalEmitOptions(
        inputPath: positional[0],
        outputPath: positional[1],
        poamPath: poamPath,
        retentionDays: retentionDays
    )
}

func usage() {
    let msg = """
    Usage: oscal-emit [--retention-days N] [--poam <poam.json>] <audit-records.jsonl> <assessment-results.json>

    Appends one OSCAL Observation per AuditRecord in the input JSONL to the
    output Assessment Results document. The output is created if missing.

    --retention-days N   Optional pruning of observations older than N days
                         from the output document. Default: no pruning
                         (STORY-037 §9 calls out the 90-day rolling window
                         as the system-wide default, configured in CI).
    --poam <path>        Cross-link elevated (chain-break) observations
                         into the POA&M at <path> by appending their UUIDs
                         to the chain-break item's related-observations.
                         Idempotent — re-runs do not duplicate references.

    Exit codes: 0 success, 2 usage, 3 input read error, 4 output write
    error, 5 AuditRecord parse error.
    """
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
}

func emit(_ opts: OscalEmitOptions) -> Int32 {
    let inputURL = URL(fileURLWithPath: opts.inputPath)
    let outputURL = URL(fileURLWithPath: opts.outputPath)

    // Read input file. Missing input is a hard error — but an empty file
    // is fine; oscal-emit on an empty stream is a no-op that still
    // touches metadata.last-modified so downstream "did the pipeline
    // run" checks remain truthy.
    let inputContents: String
    do {
        inputContents = try String(contentsOf: inputURL, encoding: .utf8)
    } catch {
        FileHandle.standardError.write("oscal-emit: cannot read \(opts.inputPath): \(error)\n".data(using: .utf8)!)
        return 3
    }

    // Parse JSONL → AuditRecord. Each line independent; tolerate blank
    // lines and skip-and-warn on malformed lines.
    let lines = inputContents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var records: [AuditRecord] = []
    var hadParseError = false
    let decoder = JSONDecoder()
    for (idx, raw) in lines.enumerated() {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty { continue }
        guard let data = line.data(using: .utf8) else { continue }
        do {
            let rec = try decoder.decode(AuditRecord.self, from: data)
            records.append(rec)
        } catch {
            hadParseError = true
            FileHandle.standardError.write("oscal-emit: skipping unparseable AuditRecord at line \(idx + 1): \(error)\n".data(using: .utf8)!)
        }
    }

    let doc: OscalAssessmentResultsDocument
    do {
        doc = try OscalAssessmentResultsDocument.loadOrCreate(at: outputURL)
    } catch {
        FileHandle.standardError.write("oscal-emit: cannot read existing AR at \(opts.outputPath): \(error)\n".data(using: .utf8)!)
        return 3
    }

    let now = Date()
    let emitter = OscalObservationEmitter()
    var appended = emitter.append(observationsFrom: records, into: doc, now: now)

    // Optional retention pruning. The rolling window applies per
    // observation's `collected` timestamp. Pruning preserves append-only
    // semantics for retained observations: only the oldest entries
    // (already on the back side of the window) are dropped, the rest
    // are untouched.
    if let days = opts.retentionDays, days > 0 {
        appended = prune(appended, olderThanDays: days, now: now)
    }

    do {
        try appended.write(to: outputURL)
    } catch {
        FileHandle.standardError.write("oscal-emit: cannot write \(opts.outputPath): \(error)\n".data(using: .utf8)!)
        return 4
    }

    // STORY-037 §2: "Hash-chain breaks ... a POA&M item is auto-opened
    // with status 'open' referencing the observation." Wire the elevated
    // observations' UUIDs into the chain-break POA&M item's
    // related-observations, so the POA&M ↔ AR cross-reference is two-way.
    var poamLinkCount = 0
    if let poamPath = opts.poamPath {
        let poamURL = URL(fileURLWithPath: poamPath)
        do {
            let priorPoam = try OscalPoamDocument.load(from: poamURL)
            let elevated = emitter.elevatedObservations(in: appended.observations)
            let updated = emitter.autoOpenChainBreakItems(in: priorPoam, forElevatedObservations: elevated, now: now)
            if updated != priorPoam {
                try updated.write(to: poamURL)
                if let item = updated.planOfActionAndMilestones.poamItems.first(where: { $0.uuid.lowercased() == OscalObservationEmitter.chainBreakRiskUuid.lowercased() }) {
                    let before = priorPoam.planOfActionAndMilestones.poamItems.first(where: { $0.uuid.lowercased() == OscalObservationEmitter.chainBreakRiskUuid.lowercased() })?.relatedObservations?.count ?? 0
                    poamLinkCount = (item.relatedObservations?.count ?? 0) - before
                }
            }
        } catch {
            FileHandle.standardError.write("oscal-emit: warning — could not update POA&M at \(poamPath): \(error)\n".data(using: .utf8)!)
        }
    }

    // Stable, machine-greppable success line for CI.
    let appendedCount = appended.observations.count - doc.observations.count
    let observationCount = appended.observations.count
    print("oscal-emit: ok  records=\(records.count)  appended=\(max(appendedCount, 0))  observations_total=\(observationCount)  poam_chain_break_links_added=\(poamLinkCount)  output=\(opts.outputPath)")

    return hadParseError ? 5 : 0
}

func prune(_ doc: OscalAssessmentResultsDocument, olderThanDays days: Int, now: Date) -> OscalAssessmentResultsDocument {
    let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
    var body = doc.assessmentResults
    guard !body.results.isEmpty else { return doc }
    body.results[0].observations.removeAll { obs in
        guard let collected = OscalAssessmentResultsDocument.parse(obs.collected) else { return false }
        return collected < cutoff
    }
    body.metadata = OscalMetadata(
        title: body.metadata.title,
        lastModified: OscalAssessmentResultsDocument.iso8601(now),
        version: body.metadata.version,
        oscalVersion: body.metadata.oscalVersion,
        parties: body.metadata.parties
    )
    return OscalAssessmentResultsDocument(assessmentResults: body)
}

// MARK: - Entry

guard let opts = parseOptions(CommandLine.arguments) else {
    usage()
    exit(2)
}
exit(emit(opts))
