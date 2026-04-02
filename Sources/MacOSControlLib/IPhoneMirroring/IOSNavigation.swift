import Foundation

public enum IOSNavigation {
    /// Go to Home screen (Cmd+1).
    public static func home() async throws {
        try await MirroringWindowDetector.activateAndFocus()
        try await KeyboardControl.pressKeys(keys: [["cmd", "1"]])
    }

    /// Open App Switcher (Cmd+2).
    public static func appSwitcher() async throws {
        try await MirroringWindowDetector.activateAndFocus()
        try await KeyboardControl.pressKeys(keys: [["cmd", "2"]])
    }

    /// Open Spotlight search (Cmd+3).
    public static func spotlight() async throws {
        try await MirroringWindowDetector.activateAndFocus()
        try await KeyboardControl.pressKeys(keys: [["cmd", "3"]])
    }
}
