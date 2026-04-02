import Foundation
import AppKit

public enum IPhoneTextInput {
    /// Type text by pasting via clipboard. Saves and restores previous clipboard contents.
    public static func typeText(_ text: String) async throws {
        try await MirroringWindowDetector.activateAndFocus()

        let pasteboard = NSPasteboard.general

        // Save current clipboard
        let previousContent = pasteboard.string(forType: .string)

        // Set clipboard to new text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Paste via Cmd+V
        try await KeyboardControl.pressKeys(keys: [["cmd", "v"]])

        // Wait for paste to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Restore previous clipboard
        pasteboard.clearContents()
        if let previous = previousContent {
            pasteboard.setString(previous, forType: .string)
        }
    }

    /// Clear text field: Cmd+A then Delete.
    public static func clearText() async throws {
        try await MirroringWindowDetector.activateAndFocus()

        // Select all
        try await KeyboardControl.pressKeys(keys: [["cmd", "a"]])
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Delete
        try await KeyboardControl.pressKeys(keys: ["delete"])
    }

    /// Press a key with optional modifiers.
    public static func pressKey(key: String, modifiers: [String] = []) async throws {
        try await MirroringWindowDetector.activateAndFocus()

        if modifiers.isEmpty {
            try await KeyboardControl.pressKeys(keys: [key])
        } else {
            var combo = modifiers
            combo.append(key)
            try await KeyboardControl.pressKeys(keys: [combo])
        }
    }
}
