import Foundation

public final class MenuItemNormalizer {

    public init() {}

    public func normalize(_ name: String) -> String {
        var s = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasSuffix("\u{2026}") {
            s = String(s.dropLast())
        } else if s.hasSuffix("...") {
            s = String(s.dropLast(3))
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
