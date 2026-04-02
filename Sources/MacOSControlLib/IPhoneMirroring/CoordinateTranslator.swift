import Foundation
import CoreGraphics
import AppKit

public enum CoordinateTranslator {
    private static var cachedContentRect: CGRect?
    private static var cachedForWindowSize: CGSize?

    /// Target aspect ratio for iPhone 17 Pro Max: 2868/1320 ≈ 2.1727
    /// We check height/width since the phone is displayed in portrait (taller than wide)
    private static let targetAspectRatio: Double = 19.5 / 9.0 // 2.1667
    private static let aspectRatioTolerance: Double = 0.3

    /// Calibrate: detect content rect within the mirroring window.
    @discardableResult
    public static func calibrate() async throws -> CGRect {
        let (windowID, windowBounds) = try MirroringWindowDetector.findMirroringWindow()

        // Capture the mirroring window
        guard let cgImage = CGWindowListCreateImage(
            windowBounds,
            .optionIncludingWindow,
            windowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            let fallback = heuristicContentRect(windowBounds: windowBounds)
            cachedContentRect = fallback
            cachedForWindowSize = windowBounds.size
            return fallback
        }

        // Convert to Data for VisionAnalyzer
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            let fallback = heuristicContentRect(windowBounds: windowBounds)
            cachedContentRect = fallback
            cachedForWindowSize = windowBounds.size
            return fallback
        }

        // Run rectangle detection
        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        do {
            let rectangles = try await VisionAnalyzer.detectRectangles(imageData: pngData, minimumConfidence: 0.3)

            // Find the largest rectangle matching iPhone aspect ratio
            var bestRect: CGRect?
            var bestArea: CGFloat = 0

            for rect in rectangles {
                guard let bbox = rect["boundingBox"] as? [String: Any],
                      let x = bbox["x"] as? Int,
                      let y = bbox["y"] as? Int,
                      let w = bbox["width"] as? Int,
                      let h = bbox["height"] as? Int else { continue }

                let rectWidth = CGFloat(w)
                let rectHeight = CGFloat(h)
                let area = rectWidth * rectHeight

                if matchesIPhoneAspectRatio(width: rectWidth, height: rectHeight) && area > bestArea {
                    // Convert pixel coords to screen coords (account for Retina)
                    let screenX = windowBounds.minX + CGFloat(x) / scaleFactor
                    let screenY = windowBounds.minY + CGFloat(y) / scaleFactor
                    let screenW = rectWidth / scaleFactor
                    let screenH = rectHeight / scaleFactor

                    bestRect = CGRect(x: screenX, y: screenY, width: screenW, height: screenH)
                    bestArea = area
                }
            }

            if let contentRect = bestRect {
                cachedContentRect = contentRect
                cachedForWindowSize = windowBounds.size
                return contentRect
            }
        } catch {
            // Rectangle detection failed, fall through to heuristic
        }

        // Fallback to heuristic
        let fallback = heuristicContentRect(windowBounds: windowBounds)
        cachedContentRect = fallback
        cachedForWindowSize = windowBounds.size
        return fallback
    }

    /// Translate normalized (0-1) coordinates to absolute screen coordinates.
    public static func toAbsolute(normalizedX: Double, normalizedY: Double) async throws -> CGPoint {
        // Validate range
        guard normalizedX >= 0 && normalizedX <= 1 && normalizedY >= 0 && normalizedY <= 1 else {
            throw MCPError.invalidCoordinates("Coordinates must be between 0.0 and 1.0, got (\(normalizedX), \(normalizedY))")
        }

        let contentRect = try await getContentRect()
        let absoluteX = contentRect.minX + CGFloat(normalizedX) * contentRect.width
        let absoluteY = contentRect.minY + CGFloat(normalizedY) * contentRect.height
        return CGPoint(x: absoluteX, y: absoluteY)
    }

    /// Get the cached content rect, calibrating if needed or if window size changed.
    public static func getContentRect() async throws -> CGRect {
        // Check if we need to recalibrate
        let (_, currentBounds) = try MirroringWindowDetector.findMirroringWindow()

        if let cached = cachedContentRect,
           let cachedSize = cachedForWindowSize,
           cachedSize.width == currentBounds.size.width,
           cachedSize.height == currentBounds.size.height {
            return cached
        }

        // Calibrate (or recalibrate due to window resize)
        return try await calibrate()
    }

    /// Clear calibration cache.
    public static func clearCache() {
        cachedContentRect = nil
        cachedForWindowSize = nil
    }

    // MARK: - Internal (visible for testing)

    /// Check if dimensions match iPhone aspect ratio (portrait: height/width ≈ 2.167).
    public static func matchesIPhoneAspectRatio(width: CGFloat, height: CGFloat) -> Bool {
        guard width > 0 && height > 0 else { return false }
        let ratio = max(width, height) / min(width, height)
        return abs(ratio - targetAspectRatio) <= aspectRatioTolerance
    }

    /// Fallback heuristic: 28pt title bar, content fills rest of window.
    public static func heuristicContentRect(windowBounds: CGRect) -> CGRect {
        let titleBarHeight: CGFloat = 28
        return CGRect(
            x: windowBounds.minX,
            y: windowBounds.minY + titleBarHeight,
            width: windowBounds.width,
            height: windowBounds.height - titleBarHeight
        )
    }

    /// Convert absolute screen point to normalized (0-1) coordinates relative to content rect.
    /// Used for normalizing OCR results.
    public static func toNormalized(absoluteX: CGFloat, absoluteY: CGFloat, contentRect: CGRect) -> (x: Double, y: Double) {
        let nx = Double((absoluteX - contentRect.minX) / contentRect.width)
        let ny = Double((absoluteY - contentRect.minY) / contentRect.height)
        return (x: nx, y: ny)
    }
}
