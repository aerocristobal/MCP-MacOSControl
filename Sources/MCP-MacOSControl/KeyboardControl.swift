import Foundation
import CoreGraphics
import Carbon

class KeyboardControl {

    /// Type the specified text at the current cursor position
    static func typeText(text: String) async throws {
        let source = CGEventSource(stateID: .hidSystemState)

        for char in text {
            let charString = String(char)
            let utf16Chars = Array(charString.utf16)

            for utf16Char in utf16Chars {
                if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                   let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {

                    keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: [utf16Char])
                    keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: [utf16Char])

                    keyDown.post(tap: .cghidEventTap)
                    keyUp.post(tap: .cghidEventTap)

                    // Small delay between characters for more natural typing
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
            }
        }
    }

    /// Press a single key or a combination of keys
    static func pressKeys(keys: [Any]) async throws {
        if keys.count == 1, let key = keys[0] as? String {
            // Single key press
            try pressSingleKey(key: key)
        } else if let keyArray = keys as? [[String]] {
            // Handle key combinations like [["cmd", "c"], ["cmd", "v"]]
            for combination in keyArray {
                if combination.count == 1 {
                    try pressSingleKey(key: combination[0])
                } else {
                    try pressKeyCombination(keys: combination)
                }
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05s
            }
        } else if let keyArray = keys as? [String] {
            // Handle simple array of keys to be pressed in sequence
            for key in keyArray {
                try pressSingleKey(key: key)
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05s
            }
        }
    }

    /// Hold down a specific keyboard key
    static func keyDown(key: String) throws {
        guard let keyCode = getKeyCode(for: key) else {
            throw NSError(domain: "KeyboardControl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid key: \(key)"])
        }

        let source = CGEventSource(stateID: .hidSystemState)
        if let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            event.post(tap: .cghidEventTap)
        }
    }

    /// Release a specific keyboard key
    static func keyUp(key: String) throws {
        guard let keyCode = getKeyCode(for: key) else {
            throw NSError(domain: "KeyboardControl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid key: \(key)"])
        }

        let source = CGEventSource(stateID: .hidSystemState)
        if let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            event.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Private Helper Methods

    /// Press a single key
    private static func pressSingleKey(key: String) throws {
        guard let keyCode = getKeyCode(for: key) else {
            throw NSError(domain: "KeyboardControl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid key: \(key)"])
        }

        let source = CGEventSource(stateID: .hidSystemState)
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }

    /// Press a combination of keys (e.g., cmd+c)
    private static func pressKeyCombination(keys: [String]) throws {
        let source = CGEventSource(stateID: .hidSystemState)
        var keyCodes: [CGKeyCode] = []
        var flags: CGEventFlags = []

        // Convert keys to key codes and build flags
        for key in keys {
            if let modifier = getModifierFlag(for: key) {
                flags.insert(modifier)
            }
            if let keyCode = getKeyCode(for: key) {
                keyCodes.append(keyCode)
            }
        }

        // Press all modifier keys down
        for key in keys {
            if getModifierFlag(for: key) != nil {
                if let keyCode = getKeyCode(for: key),
                   let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
                    event.flags = flags
                    event.post(tap: .cghidEventTap)
                }
            }
        }

        // Press the main key(s)
        for key in keys {
            if getModifierFlag(for: key) == nil {
                if let keyCode = getKeyCode(for: key) {
                    if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
                       let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
                        keyDown.flags = flags
                        keyUp.flags = flags
                        keyDown.post(tap: .cghidEventTap)
                        keyUp.post(tap: .cghidEventTap)
                    }
                }
            }
        }

        // Release all modifier keys
        for key in keys.reversed() {
            if getModifierFlag(for: key) != nil {
                if let keyCode = getKeyCode(for: key),
                   let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
                    event.post(tap: .cghidEventTap)
                }
            }
        }
    }

    /// Get CGKeyCode for a given key string
    private static func getKeyCode(for key: String) -> CGKeyCode? {
        let keyMap: [String: CGKeyCode] = [
            // Letters
            "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E, "f": 0x03, "g": 0x05,
            "h": 0x04, "i": 0x22, "j": 0x26, "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D,
            "o": 0x1F, "p": 0x23, "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11, "u": 0x20,
            "v": 0x09, "w": 0x0D, "x": 0x07, "y": 0x10, "z": 0x06,

            // Numbers
            "0": 0x1D, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
            "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19,

            // Function keys
            "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76, "f5": 0x60, "f6": 0x61,
            "f7": 0x62, "f8": 0x64, "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F,

            // Special keys
            "return": 0x24, "enter": 0x4C, "tab": 0x30, "space": 0x31, "delete": 0x33,
            "escape": 0x35, "esc": 0x35, "backspace": 0x33,

            // Modifier keys
            "command": 0x37, "cmd": 0x37, "shift": 0x38, "capslock": 0x39,
            "option": 0x3A, "alt": 0x3A, "control": 0x3B, "ctrl": 0x3B,
            "rightcommand": 0x36, "rightshift": 0x3C, "rightoption": 0x3D, "rightcontrol": 0x3E,

            // Arrow keys
            "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,

            // Other keys
            "home": 0x73, "end": 0x77, "pageup": 0x74, "pagedown": 0x79,
            "minus": 0x1B, "equal": 0x18, "leftbracket": 0x21, "rightbracket": 0x1E,
            "quote": 0x27, "semicolon": 0x29, "backslash": 0x2A, "comma": 0x2B,
            "slash": 0x2C, "period": 0x2F, "grave": 0x32
        ]

        return keyMap[key.lowercased()]
    }

    /// Get modifier flag for a given key string
    private static func getModifierFlag(for key: String) -> CGEventFlags? {
        switch key.lowercased() {
        case "command", "cmd":
            return .maskCommand
        case "shift":
            return .maskShift
        case "control", "ctrl":
            return .maskControl
        case "option", "alt":
            return .maskAlternate
        default:
            return nil
        }
    }
}
