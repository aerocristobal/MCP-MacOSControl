import Foundation

/// Parsed `macos://...` URI: the canonical path (scheme + host + path,
/// without query) plus a flat query map. Stable enough for `==` lookups
/// against `ResourceURIs.activeApplication` / `.activeWindowTree`.
public struct ParsedResourceURI: Equatable {
    public let canonicalURI: String
    public let queryItems: [String: String]

    public init(canonicalURI: String, queryItems: [String: String]) {
        self.canonicalURI = canonicalURI
        self.queryItems = queryItems
    }

    /// max_depth in [1, 50]. Default 6 (matches accessibility_tree).
    /// Invalid or missing values clamp to the default.
    public func maxDepth(default defaultValue: Int = 6) -> Int {
        guard let raw = queryItems["max_depth"], let parsed = Int(raw) else {
            return defaultValue
        }
        return min(max(parsed, 1), 50)
    }
}

public enum ResourceURIs {
    public static let activeApplication = "macos://ui/active-application"
    public static let activeWindowTree = "macos://ui/active-window-tree"
}

public enum ResourceURIParser {
    /// Parse with a permissive splitter (`URLComponents` rejects `macos://`
    /// schemes inconsistently across SDK versions, so we hand-roll a tiny
    /// scheme+path+query split that's enough for these two well-known URIs).
    public static func parse(_ raw: String) -> ParsedResourceURI {
        let (pathPart, queryPart) = splitOnQuery(raw)
        let queryItems = parseQuery(queryPart)
        return ParsedResourceURI(canonicalURI: pathPart, queryItems: queryItems)
    }

    private static func splitOnQuery(_ raw: String) -> (String, String) {
        guard let qIndex = raw.firstIndex(of: "?") else { return (raw, "") }
        return (String(raw[..<qIndex]), String(raw[raw.index(after: qIndex)...]))
    }

    private static func parseQuery(_ raw: String) -> [String: String] {
        guard !raw.isEmpty else { return [:] }
        var out: [String: String] = [:]
        for pair in raw.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard let key = kv.first.map(String.init) else { continue }
            let value = kv.count > 1 ? String(kv[1]) : ""
            out[key] = value.removingPercentEncoding ?? value
        }
        return out
    }
}
