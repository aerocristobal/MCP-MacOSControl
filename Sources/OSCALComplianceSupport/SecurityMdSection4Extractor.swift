// STORY-037 — Extracts the §4 accepted-risk statements from SECURITY.md
// so the POA&M coverage checker can verify each one has a POA&M item.
//
// The §4 structure SECURITY.md uses today:
//   ## 4. Threat Catalog
//   ### 4.1 <title>
//       ... **Accepted residual risk.** <text>
//       ... or **Acknowledged residual risk.** <text>
//   ### 4.2 <title>
//       ... **Accepted residual risk.** <text>
//   ### 4.3 <title>
//       ... **Accepted residual risk.** <text>
//   ### 4.4 <title>
//       ... **Acknowledged residual risk.** <text>
//
// A "§4 accepted-risk statement" = any §4.N subsection whose body
// contains the substring "Accepted residual risk" OR "Acknowledged
// residual risk". The substring search is intentionally tolerant —
// the canonical headings are bolded, but the checker shouldn't break
// if a maintainer drops the **bold**.

import Foundation

public struct SecurityMdSection4Extractor {

    public struct AcceptedRiskStatement: Equatable {
        public let section: String   // e.g. "4.1", "4.4"
        public let title: String     // e.g. "Arbitrary code execution via AppleScript"
        public let body: String      // the full subsection body, useful for downstream display

        public init(section: String, title: String, body: String) {
            self.section = section
            self.title = title
            self.body = body
        }
    }

    public init() {}

    public func extract(from markdown: String) -> [AcceptedRiskStatement] {
        var results: [AcceptedRiskStatement] = []

        let lines = markdown.components(separatedBy: "\n")
        let topLevelHeaderRegex = try! NSRegularExpression(pattern: #"^##\s+(\d+)\.\s"#)
        let subSectionRegex = try! NSRegularExpression(pattern: #"^###\s+(4\.\d+)\s+(.+?)\s*$"#)

        var inSection4 = false
        var currentSection: String?
        var currentTitle: String?
        var currentBody = ""

        func flush() {
            guard let section = currentSection, let title = currentTitle else { return }
            let body = currentBody
            // Match-quality: either canonical bold heading, or a tolerant
            // case-insensitive match. The catalog uses bolded headings; the
            // checker also accepts unbolded as a fallback so editing the
            // doc doesn't accidentally hide a risk.
            let bodyLowered = body.lowercased()
            let hasAcceptedRisk = bodyLowered.contains("accepted residual risk")
                || bodyLowered.contains("acknowledged residual risk")
            if hasAcceptedRisk {
                results.append(AcceptedRiskStatement(section: section, title: title, body: body))
            }
            currentSection = nil
            currentTitle = nil
            currentBody = ""
        }

        for line in lines {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)

            if let m = topLevelHeaderRegex.firstMatch(in: line, range: range),
               let r = Range(m.range(at: 1), in: line) {
                let topNum = String(line[r])
                if currentSection != nil { flush() }
                inSection4 = (topNum == "4")
                continue
            }

            guard inSection4 else { continue }

            if let m = subSectionRegex.firstMatch(in: line, range: range),
               let sectionRange = Range(m.range(at: 1), in: line),
               let titleRange = Range(m.range(at: 2), in: line) {
                if currentSection != nil { flush() }
                currentSection = String(line[sectionRange])
                currentTitle = String(line[titleRange])
                currentBody = ""
                continue
            }

            if currentSection != nil {
                if !currentBody.isEmpty { currentBody += "\n" }
                currentBody += line
            }
        }

        // Flush the last subsection if we never saw another top-level header.
        flush()

        return results
    }
}
