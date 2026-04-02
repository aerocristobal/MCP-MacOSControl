import Foundation
import CoreGraphics
import AppKit

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

    /// Open an iOS app by name via Spotlight search.
    public static func openApp(name: String) async throws -> String {
        try await spotlight()
        try await Task.sleep(nanoseconds: 300_000_000)

        try await IPhoneTextInput.typeText(name)
        try await Task.sleep(nanoseconds: 500_000_000)

        // Capture iPhone screen and run OCR
        let (windowID, windowBounds) = try MirroringWindowDetector.findMirroringWindow()
        let contentRect = try await CoordinateTranslator.getContentRect()

        guard let fullImage = CGWindowListCreateImage(
            windowBounds, .optionIncludingWindow, windowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else { throw MCPError.mirroringNotRunning }

        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
        let cropX = (contentRect.minX - windowBounds.minX) * scaleFactor
        let cropY = (contentRect.minY - windowBounds.minY) * scaleFactor
        let cropW = contentRect.width * scaleFactor
        let cropH = contentRect.height * scaleFactor

        guard let croppedImage = fullImage.cropping(to: CGRect(x: cropX, y: cropY, width: cropW, height: cropH)) else {
            throw MCPError.calibrationFailed("Failed to crop iPhone screen")
        }

        let nsImage = NSImage(cgImage: croppedImage, size: NSSize(width: croppedImage.width, height: croppedImage.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw MCPError.calibrationFailed("Failed to convert screenshot")
        }

        let ocrResults = try await OCRProcessor.performOCR(on: pngData)

        for entry in ocrResults {
            guard entry.count >= 3, let text = entry[1] as? String else { continue }
            if text.localizedCaseInsensitiveContains(name) {
                if let coords = entry[0] as? [[Any]], coords.count >= 4 {
                    var sumX = 0.0, sumY = 0.0
                    for point in coords {
                        if let px = point[0] as? Int, let py = point[1] as? Int {
                            sumX += Double(px); sumY += Double(py)
                        } else if let px = point[0] as? Double, let py = point[1] as? Double {
                            sumX += px; sumY += py
                        }
                    }
                    let cx = sumX / Double(coords.count) / Double(croppedImage.width)
                    let cy = sumY / Double(coords.count) / Double(croppedImage.height)
                    try await GestureEngine.tap(x: cx, y: cy)
                    return "Opened \(name) (tapped at \(String(format: "%.2f", cx)), \(String(format: "%.2f", cy)))"
                }
            }
        }

        try await home()
        throw MCPError.windowNotFound("App '\(name)' not found in Spotlight results")
    }
}
