import Foundation
import AppKit
import CoreGraphics

class WindowManagement {

    /// List all open windows on the system
    static func listWindows() throws -> [[String: Any]] {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            throw NSError(domain: "WindowManagement", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get window list"])
        }

        var windows: [[String: Any]] = []

        for window in windowList {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let windowID = window[kCGWindowNumber as String] as? Int,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else {
                continue
            }

            // Get window title (may be empty for some windows)
            let title = (window[kCGWindowName as String] as? String) ?? ownerName

            // Get window bounds
            let x = Int(bounds["X"] ?? 0)
            let y = Int(bounds["Y"] ?? 0)
            let width = Int(bounds["Width"] ?? 0)
            let height = Int(bounds["Height"] ?? 0)

            // Get window layer
            let layer = window[kCGWindowLayer as String] as? Int ?? 0

            // Get window state flags
            let isOnScreen = (window[kCGWindowIsOnscreen as String] as? Bool) ?? false
            let alpha = window[kCGWindowAlpha as String] as? CGFloat ?? 1.0

            let windowInfo: [String: Any] = [
                "windowID": windowID,
                "title": title,
                "ownerName": ownerName,
                "x": x,
                "y": y,
                "width": width,
                "height": height,
                "layer": layer,
                "isOnScreen": isOnScreen,
                "alpha": alpha
            ]

            windows.append(windowInfo)
        }

        return windows
    }

    /// Activate a window by matching its title
    static func activateWindow(titlePattern: String, useRegex: Bool = false, threshold: Int = 60) throws {
        let windows = try listWindows()

        // Find matching window
        var matchedWindow: [String: Any]?
        var bestScore = 0

        for window in windows {
            guard let title = window["title"] as? String else { continue }

            if useRegex {
                if let regex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive) {
                    let range = NSRange(title.startIndex..., in: title)
                    if regex.firstMatch(in: title, options: [], range: range) != nil {
                        matchedWindow = window
                        break
                    }
                }
            } else {
                // Fuzzy matching
                let score = fuzzyMatch(pattern: titlePattern, text: title)
                if score >= threshold && score > bestScore {
                    bestScore = score
                    matchedWindow = window
                }
            }
        }

        guard let window = matchedWindow else {
            throw NSError(domain: "WindowManagement", code: 2, userInfo: [NSLocalizedDescriptionKey: "No window found matching pattern: \(titlePattern)"])
        }

        // Get the owner name and use NSRunningApplication to activate
        guard let ownerName = window["ownerName"] as? String else {
            throw NSError(domain: "WindowManagement", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get window owner"])
        }

        // Find the running application
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.localizedName == ownerName }) {
            let success = app.activate(options: [.activateIgnoringOtherApps])
            if !success {
                throw NSError(domain: "WindowManagement", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to activate application: \(ownerName)"])
            }
        } else {
            throw NSError(domain: "WindowManagement", code: 5, userInfo: [NSLocalizedDescriptionKey: "Application not found: \(ownerName)"])
        }
    }

    /// Simple fuzzy matching algorithm
    private static func fuzzyMatch(pattern: String, text: String) -> Int {
        let patternLower = pattern.lowercased()
        let textLower = text.lowercased()

        // Exact match
        if textLower == patternLower {
            return 100
        }

        // Contains match
        if textLower.contains(patternLower) {
            return 90
        }

        // Calculate similarity based on common characters
        let patternChars = Set(patternLower)
        let textChars = Set(textLower)
        let commonChars = patternChars.intersection(textChars)

        let similarity = Double(commonChars.count) / Double(max(patternChars.count, textChars.count))
        return Int(similarity * 80)
    }
}
