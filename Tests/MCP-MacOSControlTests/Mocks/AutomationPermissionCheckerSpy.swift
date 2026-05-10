import Foundation
@testable import MacOSControlLib

final class AutomationPermissionCheckerSpy: AutomationPermissionChecking {
    var stubbedResult: AutomationPermissionResult = .skipped
    var stubbedExtraction: [String]?
    var checkCallCount = 0
    var extractCallCount = 0
    var lastTargetApps: [String]?

    func extractTargetApps(from script: String) -> [String] {
        extractCallCount += 1
        if let stub = stubbedExtraction { return stub }
        // Default behavior: return a single app if a tell clause is present so
        // tests that don't override extraction still exercise the check pathway.
        let pattern = #"(?i)tell\s+application\s+"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(script.startIndex..., in: script)
        return regex.matches(in: script, options: [], range: range).compactMap { match in
            guard match.numberOfRanges >= 2,
                  let r = Range(match.range(at: 1), in: script) else { return nil }
            return String(script[r])
        }
    }

    func check(targetApps: [String]) -> AutomationPermissionResult {
        checkCallCount += 1
        lastTargetApps = targetApps
        return stubbedResult
    }
}
