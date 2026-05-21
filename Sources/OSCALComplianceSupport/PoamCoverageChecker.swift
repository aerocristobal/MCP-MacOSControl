// STORY-037 — Cross-checks SECURITY.md §4 against the POA&M.
//
// OSCAL POA&M 1.1.2 puts the substantive state on `risks[]`, not
// `poam-items[]`. Each §4 statement maps to one OscalRisk carrying
// `props[name=security-md-section]`. The checker rules:
//
//   1. Every §4.N accepted-risk statement must have at least one Risk
//      with `props[name=security-md-section]` == "4.N" that is in an
//      "open"-like status ("open", "investigating", "remediating",
//      "deviation-requested", "deviation-approved").
//   2. Every Risk that names a `security-md-section` must point at a
//      §4.N that exists in the document.
//   3. Closed risks (`status: closed`) must carry a non-empty risk-log
//      entry citing the closure (a "story" or "commit" reference).

import Foundation

public struct PoamCoverageReport: Equatable {
    public let coveredSections: Set<String>         // §4.N values that have at least one Open-like risk
    public let acceptedSections: Set<String>        // §4.N values found in SECURITY.md
    public let missingSections: Set<String>         // accepted in §4 but no open-like risk
    public let extraSections: Set<String>           // Risk references §4.N that doesn't exist
    public let openRisksForClosedSections: [String] // Risks still open-like whose §4 statement is gone
    public let closedRisksLackingEvidence: [String] // Risks with status=closed but empty/uninformative risk-log
}

public enum PoamCoverageError: Error, CustomStringConvertible {
    case poamUnreadable(path: String, underlying: Error)
    case poamInvalidJson(path: String, underlying: Error)
    case securityMdUnreadable(path: String, underlying: Error)

    public var description: String {
        switch self {
        case .poamUnreadable(let p, let e):
            return "POA&M at \(p) could not be read: \(e)"
        case .poamInvalidJson(let p, let e):
            return "POA&M at \(p) is not valid JSON: \(e)"
        case .securityMdUnreadable(let p, let e):
            return "SECURITY.md at \(p) could not be read: \(e)"
        }
    }
}

public struct PoamCoverageChecker {

    /// Statuses that count as "still open" from the perspective of an
    /// accepted-risk statement still appearing in SECURITY.md §4. OSCAL's
    /// risk-status enum splits "open" across several distinct values;
    /// only "closed" means the risk is no longer active.
    public static let openLikeStatuses: Set<String> = [
        "open",
        "investigating",
        "remediating",
        "deviation-requested",
        "deviation-approved"
    ]

    public init() {}

    // MARK: - Static report API (used by tests with raw strings)

    public static func report(securityMd: String, poam: OscalPoamDocument) -> PoamCoverageReport {
        let statements = SecurityMdSection4Extractor().extract(from: securityMd)
        let acceptedSections = Set(statements.map { $0.section })

        // Group risks by their security-md-section prop. Risks without
        // the prop (e.g. the auto-opened chain-break risk) are not
        // §4-derived and don't participate in coverage.
        var sectionToRisks: [String: [OscalRisk]] = [:]
        for risk in poam.risks {
            if let s = risk.securityMdSection {
                sectionToRisks[s, default: []].append(risk)
            }
        }

        // A §4 statement is "covered" iff at least one open-like risk
        // points at it. A closed risk alone does not satisfy coverage —
        // the closure means the risk is gone and the §4 statement
        // should also be gone.
        let openCoverageSections: Set<String> = Set(sectionToRisks.compactMap { kv -> String? in
            let openLike = kv.value.contains { Self.openLikeStatuses.contains($0.status) }
            return openLike ? kv.key : nil
        })

        let missing = acceptedSections.subtracting(openCoverageSections)

        let referencedSections = Set(sectionToRisks.keys)
        let extras = referencedSections.subtracting(acceptedSections)

        // §4 statement removed but risk is still open-like → needs a status flip.
        var stillOpenForClosed: [String] = []
        for (section, risks) in sectionToRisks where !acceptedSections.contains(section) {
            for r in risks where Self.openLikeStatuses.contains(r.status) {
                stillOpenForClosed.append(r.uuid)
            }
        }

        // Closed risks must carry a non-empty risk-log entry citing the
        // closure (a story or commit). An empty risk-log is a red flag.
        var closedNoEvidence: [String] = []
        for risk in poam.risks where risk.status == "closed" {
            let entries = risk.riskLog?.entries ?? []
            let nonEmpty = entries.contains { entry in
                let body = (entry.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !body.isEmpty else { return false }
                let lowered = body.lowercased()
                return lowered.contains("story") || lowered.contains("commit") || lowered.contains("evidence")
            }
            if !nonEmpty { closedNoEvidence.append(risk.uuid) }
        }

        return PoamCoverageReport(
            coveredSections: openCoverageSections,
            acceptedSections: acceptedSections,
            missingSections: missing,
            extraSections: extras,
            openRisksForClosedSections: stillOpenForClosed,
            closedRisksLackingEvidence: closedNoEvidence
        )
    }

    // MARK: - File-based API (used by CI)

    public func report(securityMdPath: String, poamPath: String) throws -> PoamCoverageReport {
        let md: String
        do {
            md = try String(contentsOfFile: securityMdPath, encoding: .utf8)
        } catch {
            throw PoamCoverageError.securityMdUnreadable(path: securityMdPath, underlying: error)
        }

        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: poamPath))
        } catch {
            throw PoamCoverageError.poamUnreadable(path: poamPath, underlying: error)
        }

        let poam: OscalPoamDocument
        do {
            poam = try JSONDecoder().decode(OscalPoamDocument.self, from: data)
        } catch {
            throw PoamCoverageError.poamInvalidJson(path: poamPath, underlying: error)
        }

        return Self.report(securityMd: md, poam: poam)
    }
}
