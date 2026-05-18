import Foundation

/// STORY-018 — pure validator for the optional `bundle_identifier` filter.
/// Rejects anything that won't parse as an Apple reverse-DNS bundle id before
/// the bridge subscribes, so a typo fails fast instead of silently never
/// matching and timing out (Story Q6).
public enum BundleIdentifierValidator {

    /// Throws `InvalidBundleIdentifierError` if `value` is not a reverse-DNS
    /// bundle identifier (at least two `.`-separated tokens of
    /// `[A-Za-z0-9-]`).
    public static func validate(_ value: String) throws {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard
            let regex = try? NSRegularExpression(pattern: InvalidBundleIdentifierError.pattern),
            regex.firstMatch(in: value, range: range) != nil
        else {
            throw InvalidBundleIdentifierError(bundleIdentifier: value)
        }
    }
}
