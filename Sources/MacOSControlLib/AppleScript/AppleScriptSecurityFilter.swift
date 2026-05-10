import Foundation

public struct AppleScriptSecurityError: Error, Equatable {
    public let matchedRule: String
    public let detail: String

    public init(matchedRule: String, detail: String) {
        self.matchedRule = matchedRule
        self.detail = detail
    }
}

public protocol AppleScriptSecurityFiltering {
    func validate(_ script: String) throws
}

public final class AppleScriptSecurityFilter: AppleScriptSecurityFiltering {

    private struct Rule {
        let name: String
        let pattern: String
        let detail: String
    }

    private let rules: [Rule] = [
        Rule(name: "do_shell_script",
             pattern: #"\bdo\s+shell\s+script\b"#,
             detail: "do shell script invocation rejected by security policy"),
        Rule(name: "do_javascript",
             pattern: #"\bdo\s+javascript\b"#,
             detail: "do JavaScript invocation rejected by security policy"),
        Rule(name: "load_script",
             pattern: #"\bload\s+script\b"#,
             detail: "load script invocation rejected by security policy"),
        Rule(name: "system_events_tell",
             pattern: #"\btell\s+application\s+\"system\s+events\""#,
             detail: "tell application \"System Events\" rejected by security policy"),
        Rule(name: "path_traversal_relative",
             pattern: #"\.\./"#,
             detail: "path traversal pattern (../) rejected by security policy"),
        Rule(name: "path_etc",
             pattern: #"(?<![A-Za-z0-9_])/etc(?:/|\b)"#,
             detail: "/etc path reference rejected by security policy"),
        Rule(name: "path_private",
             pattern: #"(?<![A-Za-z0-9_])/private(?:/|\b)"#,
             detail: "/private path reference rejected by security policy"),
        Rule(name: "path_ssh",
             pattern: #"~/\.ssh"#,
             detail: "~/.ssh path reference rejected by security policy")
    ]

    public init() {}

    public func validate(_ script: String) throws {
        let normalized = normalize(script)
        for rule in rules {
            if matches(rule.pattern, in: normalized) {
                throw AppleScriptSecurityError(matchedRule: rule.name, detail: rule.detail)
            }
        }
    }

    /// Strips block comments and line comments, preserves string-literal content
    /// (so a quoted string containing `do shell script` is still rejected — strict
    /// rule per resolved Open Question 1), then lowercases.
    private func normalize(_ script: String) -> String {
        var working = script

        // Strip block comments: (* ... *) — non-greedy, multiline
        if let blockRegex = try? NSRegularExpression(
            pattern: #"\(\*[\s\S]*?\*\)"#,
            options: []
        ) {
            let range = NSRange(working.startIndex..., in: working)
            working = blockRegex.stringByReplacingMatches(
                in: working, options: [], range: range, withTemplate: " "
            )
        }

        // Strip line comments: -- ...\n  and  # ...\n
        if let lineRegex = try? NSRegularExpression(
            pattern: #"(?:--|#)[^\n]*"#,
            options: []
        ) {
            let range = NSRange(working.startIndex..., in: working)
            working = lineRegex.stringByReplacingMatches(
                in: working, options: [], range: range, withTemplate: " "
            )
        }

        return working.lowercased()
    }

    private func matches(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}
