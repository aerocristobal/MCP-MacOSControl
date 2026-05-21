// STORY-037 — Converts AuditRecord stream into OSCAL Observations.
//
// One record → one observation. The emitter is pure: same inputs always
// produce the same observation UUID for the same record_id, so re-runs
// are idempotent and `appending(observations:)` can deduplicate by uuid.
//
// Field map (also documented in oscal/assessment-results-mapping.md):
//
//   AuditRecord.recordId                → Observation.uuid (deterministic v5-ish derivation)
//   AuditRecord.timestampIso8601        → Observation.collected
//   AuditRecord.eventType + filter      → Observation.title, methods, control links (via EventTypeMapping)
//   AuditRecord.targetAppsExtracted     → Observation.subjects[type=component]
//   AuditRecord.hostIdentifier          → Observation.subjects[type=party]
//   AuditRecord.scriptSha256            → Observation.subjects[type=evidence] (script fingerprint)
//   AuditRecord.executionOutcome        → Observation.props[name=execution-outcome]
//   AuditRecord.filterDisposition       → Observation.props[name=filter-disposition]
//   AuditRecord.recordId                → Observation.relevant-evidence[].href (audit-records:// URI)
//
// Chain-break events also get a related-risks entry referencing AU-9,
// per the BDD scenario "Hash-chain breaks from STORY-024 generate a
// higher-severity observation".

import Foundation
import CryptoKit
import MacOSControlLib

public struct OscalObservationEmitter {

    private let mapping: EventTypeMapping

    public init(mapping: EventTypeMapping = .default) {
        self.mapping = mapping
    }

    // MARK: - Public API

    /// Converts a batch of AuditRecords into Observations, dropping any
    /// records the mapping cannot place.
    public func observations(from records: [AuditRecord]) -> [OscalObservation] {
        records.compactMap(observation(for:))
    }

    /// Convenience used by tests and the CLI — wraps `observations(from:)`
    /// and `appending(observations:)`. Reads the existing AR doc, appends
    /// only observations whose UUIDs are not already present (dedup on
    /// re-runs), and returns the new document.
    public func append(observationsFrom records: [AuditRecord], into doc: OscalAssessmentResultsDocument, now: Date = Date()) -> OscalAssessmentResultsDocument {
        let existingUuids = Set(doc.observations.map { $0.uuid })
        let new = observations(from: records).filter { !existingUuids.contains($0.uuid) }
        return doc.appending(observations: new, now: now)
    }

    // MARK: - Internal

    func observation(for record: AuditRecord) -> OscalObservation? {
        guard let entry = mapping.entry(for: record) else { return nil }

        var subjects: [OscalObservationSubject] = []

        // The "tool" subject — the MCP tool that ran. Inferred from the
        // event type because AuditRecord doesn't carry the tool name as a
        // first-class field today; the eventType → tool inference is
        // stable and documented.
        let toolName: String
        switch record.eventType {
        case .applescriptExecute: toolName = "run_applescript"
        case .menuClick: toolName = "click_menu_item"
        case .menuAlternativesLookup: toolName = "click_menu_item"   // shares tool surface
        case .chainVerificationFailure: toolName = "verify_audit_chain"
        case .administrativeForceRotateUnacked: toolName = "force_rotate_unacked"
        }
        subjects.append(OscalObservationSubject(
            subjectUuid: derivedUuid(seed: "tool:" + toolName),
            type: "tool",
            title: toolName
        ))

        // Component subjects — one per target app extracted from the script.
        for app in record.targetAppsExtracted {
            subjects.append(OscalObservationSubject(
                subjectUuid: derivedUuid(seed: "component:" + app),
                type: "component",
                title: app
            ))
        }

        // Party subject — the host identifier (single-tenant install).
        subjects.append(OscalObservationSubject(
            subjectUuid: derivedUuid(seed: "party:" + record.hostIdentifier),
            type: "party",
            title: record.hostIdentifier
        ))

        // Script-fingerprint subject (only when we have a non-empty SHA).
        if !record.scriptSha256.isEmpty && record.scriptSha256 != "0000000000000000000000000000000000000000000000000000000000000000" {
            subjects.append(OscalObservationSubject(
                subjectUuid: derivedUuid(seed: "script-sha256:" + record.scriptSha256),
                type: "evidence",
                title: "sha256:" + record.scriptSha256
            ))
        }

        // Provenance — record_hash + chain-offset land in remarks for the
        // assessor; tooling consumes the props.
        var props: [OscalProp] = [
            OscalProp(name: "filter-disposition", value: record.filterDisposition.rawValue, ns: nil, class: nil, remarks: nil),
            OscalProp(name: "execution-outcome", value: record.executionOutcome.rawValue, ns: nil, class: nil, remarks: nil),
            OscalProp(name: "audit-record-hash", value: record.recordHash, ns: nil, class: nil, remarks: nil),
            OscalProp(name: "audit-prev-hash", value: record.prevHash, ns: nil, class: nil, remarks: nil),
            OscalProp(name: "audit-schema-version", value: String(record.auditSchemaVersion), ns: nil, class: nil, remarks: nil),
            OscalProp(name: "duration-ms", value: String(record.durationMs), ns: nil, class: nil, remarks: nil)
        ]
        if let reason = record.rejectionReason {
            props.append(OscalProp(name: "rejection-reason", value: reason, ns: nil, class: nil, remarks: nil))
        }
        if let app = record.deniedApp {
            props.append(OscalProp(name: "denied-app", value: app, ns: nil, class: nil, remarks: nil))
        }
        if let code = record.scriptErrorCode {
            props.append(OscalProp(name: "script-error-code", value: String(code), ns: nil, class: nil, remarks: nil))
        }

        // Control linkage as `rel: control` links so the OSCAL graph can
        // resolve back into the component definition.
        var links: [OscalLink] = entry.controls.map {
            OscalLink(href: "#" + $0, rel: "control", text: $0.uppercased())
        }
        // Always link the original record back as evidence.
        links.append(OscalLink(
            href: "../docs/AUDIT-LOG-OPERATIONS.md#record-" + record.recordId.uuidString.lowercased(),
            rel: "evidence",
            text: "AuditRecord " + record.recordId.uuidString.lowercased()
        ))

        let evidence = [
            OscalObservationRelevantEvidence(
                href: "audit-records://" + record.timestampIso8601 + "/" + record.recordId.uuidString.lowercased(),
                description: "Source AuditRecord (STORY-024 hash-chained log)."
            )
        ]

        var relatedRisks: [OscalObservationRelatedRisk] = []
        if entry.elevated {
            // Stable risk UUID — every chain-break observation references the
            // same logical risk record. The POA&M item carrying this
            // riskUuid is the AU-9 / chain-break item.
            relatedRisks.append(OscalObservationRelatedRisk(
                riskUuid: "f17c8b39-6f53-4bd1-93d6-c44e1aac9b91"
            ))
        }

        let remarks = remarksFor(record: record, entry: entry)

        return OscalObservation(
            uuid: derivedUuid(seed: "observation:" + record.recordId.uuidString.lowercased()),
            title: entry.observationTitle,
            description: humanDescription(record: record, entry: entry),
            methods: entry.methods,
            types: ["operational"],
            subjects: subjects,
            relevantEvidence: evidence,
            collected: record.timestampIso8601,
            props: props,
            links: links,
            relatedRisks: relatedRisks.isEmpty ? nil : relatedRisks,
            remarks: remarks
        )
    }

    // MARK: - Helpers

    /// Deterministic UUID v5-like derivation from a seed string. Uses
    /// SHA-256 and rewrites the version/variant bits to v4-shape so the
    /// OSCAL CLI's UUID checker accepts the output (it validates shape,
    /// not provenance). Same seed always produces same UUID.
    private func derivedUuid(seed: String) -> String {
        let namespace = "story-037.mcp-macos-control."
        let digest = SHA256.hash(data: Data((namespace + seed).utf8))
        var bytes = Array(digest).prefix(16)
        // Set version (4) and variant (RFC 4122) bits.
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let part = { (range: Range<String.Index>) -> Substring in hex[range] }
        let idx = { (i: Int) in hex.index(hex.startIndex, offsetBy: i) }
        return "\(part(idx(0)..<idx(8)))-\(part(idx(8)..<idx(12)))-\(part(idx(12)..<idx(16)))-\(part(idx(16)..<idx(20)))-\(part(idx(20)..<idx(32)))"
    }

    private func humanDescription(record: AuditRecord, entry: EventTypeMapping.Entry) -> String {
        let apps = record.targetAppsExtracted.isEmpty ? "no extracted target app" : record.targetAppsExtracted.joined(separator: ", ")
        switch entry.observationTitle {
        case "applescript_executed":
            return "AppleScript invocation executed against \(apps) (host \(record.hostIdentifier))."
        case "applescript_rejected":
            return "AppleScript invocation rejected against \(apps). Disposition: \(record.filterDisposition.rawValue)."
        case "click_menu_item_invoked":
            return "click_menu_item invoked against \(apps)."
        case "menu_alternatives_lookup":
            return "click_menu_item alternatives lookup against \(apps)."
        case "run_applescript_audit_chain_break":
            return "Hash-chain verification failure detected by AuditChainVerifier. record_id=\(record.recordId.uuidString)."
        case "administrative_force_rotate_unacked":
            return "Operator-initiated rotation of unacknowledged audit records. host=\(record.hostIdentifier)."
        default:
            return "AuditRecord observation: \(entry.observationTitle)."
        }
    }

    private func remarksFor(record: AuditRecord, entry: EventTypeMapping.Entry) -> String {
        var parts: [String] = []
        parts.append("Source AuditRecord: \(record.recordId.uuidString.lowercased()).")
        parts.append("record_hash: \(record.recordHash) (prev_hash: \(record.prevHash)).")
        if entry.elevated {
            parts.append("ELEVATED severity: hash-chain integrity failure — see AU-9 control statement and POA&M item au-9-chain-break for follow-up.")
        }
        return parts.joined(separator: " ")
    }
}

public extension OscalObservationEmitter {
    /// The stable risk UUID emitted for chain-break observations. Tests
    /// rely on this matching the POA&M item's UUID for the corresponding
    /// risk entry.
    static let chainBreakRiskUuid = "f17c8b39-6f53-4bd1-93d6-c44e1aac9b91"
}
