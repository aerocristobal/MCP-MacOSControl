import Foundation
import CoreGraphics
import AppKit
import ScreenCaptureKit

@available(macOS 13.0, *)
class ScreenCapture {

    /// Check if screen recording permission is granted
    static func checkScreenRecordingPermission() -> Bool {
        // Try to capture a 1x1 pixel to test permissions
        let testRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        if let _ = CGWindowListCreateImage(
            testRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .nominalResolution
        ) {
            return true
        }
        return false
    }

    /// Take a screenshot of the entire screen or a specific window
    static func takeScreenshot(
        titlePattern: String? = nil,
        useRegex: Bool = false,
        threshold: Int = 60,
        saveToDownloads: Bool = false
    ) async throws -> (imageData: Data, metadata: [String: Any]) {

        // Check permissions first
        guard checkScreenRecordingPermission() else {
            throw NSError(
                domain: "ScreenCapture",
                code: 100,
                userInfo: [NSLocalizedDescriptionKey: "Screen Recording permission not granted. Please enable Screen Recording permission in System Settings > Privacy & Security > Screen Recording for the application running this MCP server."]
            )
        }

        var image: NSImage?
        var windowInfo: [String: Any] = [:]

        if let pattern = titlePattern {
            // Capture specific window
            if let windowImage = try await captureWindow(titlePattern: pattern, useRegex: useRegex, threshold: threshold) {
                image = windowImage.image
                windowInfo = windowImage.info
            } else {
                // Fallback to full screen if window not found
                image = try captureFullScreen()
                windowInfo["fallback"] = "Window not found, captured full screen"
            }
        } else {
            // Capture full screen
            image = try captureFullScreen()
        }

        guard let finalImage = image else {
            throw NSError(domain: "ScreenCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to capture screenshot"])
        }

        // Convert to PNG data
        guard let tiffData = finalImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ScreenCapture", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to PNG"])
        }

        // Save to downloads if requested
        if saveToDownloads {
            try saveImageToDownloads(pngData: pngData)
        }

        var metadata: [String: Any] = [
            "width": Int(finalImage.size.width),
            "height": Int(finalImage.size.height),
            "format": "png"
        ]
        metadata.merge(windowInfo) { (_, new) in new }

        return (imageData: pngData, metadata: metadata)
    }

    /// Capture the full screen
    private static func captureFullScreen() throws -> NSImage? {
        guard let screenBounds = NSScreen.main?.frame else {
            throw NSError(
                domain: "ScreenCapture",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get screen bounds. No main screen detected."]
            )
        }

        guard let cgImage = CGWindowListCreateImage(
            screenBounds,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            throw NSError(
                domain: "ScreenCapture",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to capture screen image. This usually indicates missing Screen Recording permission or the screen is locked. Screen bounds: \(screenBounds)"]
            )
        }

        let image = NSImage(cgImage: cgImage, size: screenBounds.size)
        return image
    }

    /// Capture a specific window by title pattern
    private static func captureWindow(
        titlePattern: String,
        useRegex: Bool,
        threshold: Int
    ) async throws -> (image: NSImage, info: [String: Any])? {

        // Get list of windows
        let windows = try WindowManagement.listWindows()

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

                    // Early exit optimization: if perfect match found, no need to continue
                    if score == 100 {
                        break
                    }
                }
            }
        }

        guard let window = matchedWindow,
              let windowID = window["windowID"] as? Int else {
            return nil
        }

        // Capture the window
        guard let x = window["x"] as? Int,
              let y = window["y"] as? Int,
              let width = window["width"] as? Int,
              let height = window["height"] as? Int else {
            return nil
        }

        let rect = CGRect(x: x, y: y, width: width, height: height)

        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionIncludingWindow,
            CGWindowID(windowID),
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))

        let info: [String: Any] = [
            "windowID": windowID,
            "title": window["title"] as? String ?? "",
            "x": x,
            "y": y,
            "width": width,
            "height": height
        ]

        return (image: image, info: info)
    }

    /// Save image to downloads folder
    private static func saveImageToDownloads(pngData: Data) throws {
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        // Check for custom screenshot directory
        var savePath = downloadsPath
        if let customDir = ProcessInfo.processInfo.environment["MCP_MACOS_CONTROL_SCREENSHOT_DIR"] {
            savePath = URL(fileURLWithPath: customDir)
        }

        guard let finalPath = savePath else {
            throw NSError(domain: "ScreenCapture", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to get downloads directory"])
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "screenshot_\(timestamp).png"

        let fileURL = finalPath.appendingPathComponent(filename)

        try pngData.write(to: fileURL)
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
