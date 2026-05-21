import Foundation

// Extracts NIST SP 800-53 control identifiers from SECURITY.md so the
// drift checker can compare the prose claims against the OSCAL artifact.
//
// Recognized regions: any `**XX-N**` token inside §7 or §8 of SECURITY.md.
// Narrative mentions outside those sections (e.g. §1's roadmap prose) are
// excluded — those are forward-looking references, not claimed coverage.

public struct SecurityMdControlExtractor {

    public struct ControlMention: Equatable {
        public let id: String         // lowercase, e.g. "au-2"
        public let section: String    // e.g. "7.1", "7.2", "8.3"
    }

    public init() {}

    public func extract(from markdown: String) -> [ControlMention] {
        var results: [ControlMention] = []
        var currentSection: String?
        var inRelevantTopLevel = false

        let lines = markdown.components(separatedBy: "\n")
        let topLevelHeaderRegex = try! NSRegularExpression(pattern: #"^##\s+(\d+)\.\s"#)
        let subSectionRegex = try! NSRegularExpression(pattern: #"^###\s+(\d+\.\d+)\s"#)
        // Permit 2+ letter prefixes so synthetic drift fixtures (e.g. **FAKE-99**)
        // and any future family codes flow through. Real NIST 800-53 codes are
        // always 2-letter, but the checker is also exercised against fixture text.
        let controlRegex = try! NSRegularExpression(pattern: #"\*\*([A-Z]{2,}-\d+)\*\*"#)

        for line in lines {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)

            if let m = topLevelHeaderRegex.firstMatch(in: line, range: range),
               let r = Range(m.range(at: 1), in: line) {
                let topNum = String(line[r])
                inRelevantTopLevel = (topNum == "7" || topNum == "8")
                currentSection = topNum
                continue
            }

            if let m = subSectionRegex.firstMatch(in: line, range: range),
               let r = Range(m.range(at: 1), in: line) {
                currentSection = String(line[r])
                continue
            }

            guard inRelevantTopLevel else { continue }
            guard let section = currentSection else { continue }

            let matches = controlRegex.matches(in: line, range: range)
            for match in matches {
                guard let idRange = Range(match.range(at: 1), in: line) else { continue }
                let id = String(line[idRange]).lowercased()
                let mention = ControlMention(id: id, section: section)
                if !results.contains(mention) {
                    results.append(mention)
                }
            }
        }

        return results
    }
}
