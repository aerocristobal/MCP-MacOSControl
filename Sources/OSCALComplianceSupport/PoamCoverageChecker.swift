// STORY-037 — Cross-checks SECURITY.md §4 against the POA&M.
//
// Rules:
//   1. Every §4.N accepted-risk statement must have at least one POA&M
//      item whose `props[name=security-md-section]` equals "4.N".
//   2. Every POA&M item that names a `security-md-section` must point at
//      a §4.N that exists in the document.
//   3. POA&M items with status "closed" must carry a non-empty `remarks`
//      block citing the story or evidence that closed them — the
//      checker emits a soft warning if not, but the strict mode treats
//      it as a failure.
//
// Rule 1 is the "PR adds an accepted-risk statement → must add POA&M
// item" check. Rule 2 is the "PR closes an accepted-risk statement →
// POA&M item must flip status away from open/risk-accepted" check
// (handled by a follow-up status assertion in `report.closures`).

import Foundation

public struct PoamCoverageReport: Equatable {
    public let coveredSections: Set<String>         // §4.N values that have at least one POA&M item
    public let acceptedSections: Set<String>        // §4.N values found in SECURITY.md
    public let missingSections: Set<String>         // accepted in §4 but no POA&M item
    public let extraSections: Set<String>           // POA&M item references §4.N that doesn't exist
    public let openItemsForClosedSections: [String] // POA&M items still open/risk-accepted whose §4 statement is gone
    public let closedItemsLackingEvidence: [String] // POA&M items with status=closed but empty remarks
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

    public init() {}

    // MARK: - Static report API (used by tests with raw strings)

    /// In-memory report used by tests. Takes the markdown body and the
    /// POA&M document directly.
    public static func report(securityMd: String, poam: OscalPoamDocument) -> PoamCoverageReport {
        let statements = SecurityMdSection4Extractor().extract(from: securityMd)
        let acceptedSections = Set(statements.map { $0.section })

        // POA&M items grouped by their security-md-section prop. Items
        // without the prop are ignored — historical/closed items not
        // sourced from §4 don't participate in coverage.
        var sectionToItems: [String: [OscalPoamItem]] = [:]
        for item in poam.planOfActionAndMilestones.poamItems {
            if let s = item.securityMdSection {
                sectionToItems[s, default: []].append(item)
            }
        }

        // Only consider items that are still "open" or "risk-accepted"
        // (i.e. not yet closed) as covering an accepted-risk statement.
        // A closed item alone does not satisfy coverage — the closure
        // means the risk is gone, and the corresponding §4 statement
        // should also be gone.
        let openCoverageSections: Set<String> = Set(sectionToItems.compactMap { kv -> String? in
            let openOrAccepted = kv.value.contains { ($0.status ?? "") == "open" || ($0.status ?? "") == "risk-accepted" }
            return openOrAccepted ? kv.key : nil
        })

        let missing = acceptedSections.subtracting(openCoverageSections)

        let referencedSections = Set(sectionToItems.keys)
        let extras = referencedSections.subtracting(acceptedSections)

        // §4 statement was removed but item is still open/risk-accepted →
        // needs a status flip.
        var stillOpenForClosed: [String] = []
        for (section, items) in sectionToItems where !acceptedSections.contains(section) {
            for item in items where (item.status == "open" || item.status == "risk-accepted") {
                stillOpenForClosed.append(item.uuid)
            }
        }

        // Closed items must carry non-empty remarks citing the closure.
        var closedNoEvidence: [String] = []
        for item in poam.planOfActionAndMilestones.poamItems
        where (item.status == "closed") && (item.remarks ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            closedNoEvidence.append(item.uuid)
        }

        return PoamCoverageReport(
            coveredSections: openCoverageSections,
            acceptedSections: acceptedSections,
            missingSections: missing,
            extraSections: extras,
            openItemsForClosedSections: stillOpenForClosed,
            closedItemsLackingEvidence: closedNoEvidence
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
