import Foundation

/// Pure-function script generator for menu navigation. Translates a path of
/// menu component names into AppleScript source for both clicking the leaf
/// and enumerating siblings at the failing level when not-found is observed.
public protocol MenuPathResolving {
    func script(for path: [String], application: String, doNotActivate: Bool) -> String
    func alternativesScript(for path: [String], application: String) -> String
}

/// Generates AppleScript source for clicking a menu item by hierarchical path
/// and for enumerating the items at a path's parent level (used for
/// "did-you-mean" alternatives when a click fails with not-found).
///
/// Pure functions — does not execute any script.
public final class MenuPathResolver: MenuPathResolving {

    public init() {}

    /// Generates the click script for the given path under the given app.
    ///
    /// The script optionally activates the target application, then locates
    /// the leaf menu item via the System Events menu bar hierarchy. If the
    /// item is disabled, the script raises a `-1728` error whose message
    /// contains `(item is disabled)` so the backend can disambiguate disabled
    /// from not-found. Otherwise it issues `click` on the resolved item.
    public func script(for path: [String], application: String, doNotActivate: Bool = false) -> String {
        let app = quoted(application)
        let chain = chainExpression(for: path)
        let leafName = quoted(path.last ?? "")

        var lines: [String] = []
        if !doNotActivate {
            lines.append("tell application \(app) to activate")
            lines.append("delay 0.05")
        }
        lines.append("tell application \"System Events\"")
        lines.append("    tell process \(app)")
        lines.append("        set targetItem to \(chain)")
        lines.append("        if enabled of targetItem is false then")
        lines.append("            error \"Can't get menu item \\\"\" & \(leafName) & \"\\\". (item is disabled)\" number -1728")
        lines.append("        end if")
        lines.append("        click targetItem")
        lines.append("    end tell")
        lines.append("end tell")
        return lines.joined(separator: "\n")
    }

    /// Generates an enumeration script that returns the names of every menu
    /// item at the parent level of the given path's leaf, used to populate
    /// the `alternatives` field of a `menu_item_not_found` error.
    public func alternativesScript(for path: [String], application: String) -> String {
        let app = quoted(application)
        let parentExpr = parentExpression(for: path)
        let getter: String
        if path.count <= 1 {
            getter = "get name of every menu bar item of menu bar 1"
        } else {
            getter = "get name of every menu item of \(parentExpr)"
        }

        var lines: [String] = []
        lines.append("tell application \"System Events\"")
        lines.append("    tell process \(app)")
        lines.append("        \(getter)")
        lines.append("    end tell")
        lines.append("end tell")
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    /// Builds the AppleScript reference chain for the leaf menu item.
    ///
    /// path = [A]              → menu bar item "A" of menu bar 1
    /// path = [A, leaf]        → menu item "leaf" of menu "A" of menu bar item "A" of menu bar 1
    /// path = [A, B, leaf]     → menu item "leaf" of menu "B" of menu item "B" of menu "A" of menu bar item "A" of menu bar 1
    /// path = [A, B, C, leaf]  → menu item "leaf" of menu "C" of menu item "C" of menu "B" of menu item "B" of menu "A" of menu bar item "A" of menu bar 1
    private func chainExpression(for path: [String]) -> String {
        guard !path.isEmpty else { return "" }
        if path.count == 1 {
            return "menu bar item \(quoted(path[0])) of menu bar 1"
        }

        var parts: [String] = []
        let leafIndex = path.count - 1
        parts.append("menu item \(quoted(path[leafIndex]))")

        // Intermediate components (between leaf and the top-level menu bar item).
        // For path of length n, indices n-2 down to 1 are intermediates wrapped as
        // `menu "X" of menu item "X"`. Index 0 is the top-level "menu bar item".
        if path.count >= 3 {
            for i in stride(from: leafIndex - 1, through: 1, by: -1) {
                parts.append("of menu \(quoted(path[i])) of menu item \(quoted(path[i]))")
            }
        }

        // Top-level component pairs the submenu with its menu bar item.
        parts.append("of menu \(quoted(path[0])) of menu bar item \(quoted(path[0])) of menu bar 1")
        return parts.joined(separator: " ")
    }

    /// Reference chain for the *parent* of a given path's leaf — used by
    /// `alternativesScript`. For path of length 1 this returns an empty
    /// string (the caller switches to the menu-bar-items getter).
    private func parentExpression(for path: [String]) -> String {
        guard path.count >= 2 else { return "" }
        if path.count == 2 {
            return "menu \(quoted(path[0])) of menu bar item \(quoted(path[0])) of menu bar 1"
        }

        // path.count >= 3 — parent is the submenu of path[n-2], whose chain
        // mirrors the chainExpression logic minus the leaf segment.
        let parentIndex = path.count - 2
        var parts: [String] = []
        parts.append("menu \(quoted(path[parentIndex])) of menu item \(quoted(path[parentIndex]))")
        for i in stride(from: parentIndex - 1, through: 1, by: -1) {
            parts.append("of menu \(quoted(path[i])) of menu item \(quoted(path[i]))")
        }
        parts.append("of menu \(quoted(path[0])) of menu bar item \(quoted(path[0])) of menu bar 1")
        return parts.joined(separator: " ")
    }

    /// Wraps the input as a double-quoted AppleScript string literal with
    /// `\` and `"` escaped. Backslashes are escaped first so subsequent
    /// quote-escaping does not double-escape them.
    private func quoted(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
