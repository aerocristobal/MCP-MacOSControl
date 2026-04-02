import Foundation
import CoreGraphics
import AppKit

public enum MirroringWindowDetector {
    private static var _cachedWindowID: CGWindowID?
    private static var _cachedWindowBounds: CGRect?

    public static var cachedWindowID: CGWindowID? { _cachedWindowID }
    public static var cachedWindowBounds: CGRect? { _cachedWindowBounds }

    /// Find the iPhone Mirroring window. Returns (windowID, bounds).
    public static func findMirroringWindow() throws -> (windowID: CGWindowID, bounds: CGRect) {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            throw MCPError.mirroringNotRunning
        }

        // Filter for iPhone Mirroring windows at normal layer
        let mirroringWindows = windowList.filter { window in
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let layer = window[kCGWindowLayer as String] as? Int else {
                return false
            }
            return ownerName == "iPhone Mirroring" && layer == 0
        }

        // Pick the largest window by area
        guard let bestWindow = mirroringWindows.max(by: { a, b in
            let aArea = Self.windowArea(a)
            let bArea = Self.windowArea(b)
            return aArea < bArea
        }),
        let windowID = bestWindow[kCGWindowNumber as String] as? Int,
        let boundsDict = bestWindow[kCGWindowBounds as String] as? [String: Any],
        let x = boundsDict["X"] as? CGFloat,
        let y = boundsDict["Y"] as? CGFloat,
        let width = boundsDict["Width"] as? CGFloat,
        let height = boundsDict["Height"] as? CGFloat else {
            throw MCPError.mirroringNotRunning
        }

        let bounds = CGRect(x: x, y: y, width: width, height: height)
        _cachedWindowID = CGWindowID(windowID)
        _cachedWindowBounds = bounds
        return (windowID: CGWindowID(windowID), bounds: bounds)
    }

    /// Check if iPhone Mirroring is running (non-throwing).
    public static func isMirroringRunning() -> Bool {
        let apps = NSWorkspace.shared.runningApplications
        return apps.contains { $0.localizedName == "iPhone Mirroring" }
    }

    /// Launch iPhone Mirroring app.
    public static func launchMirroringApp() throws {
        let url = URL(fileURLWithPath: "/System/Applications/iPhone Mirroring.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        let semaphore = DispatchSemaphore(value: 0)
        var launchError: Error?

        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            launchError = error
            semaphore.signal()
        }

        semaphore.wait()
        if let error = launchError {
            throw MCPError.mirroringNotAvailable
        }
    }

    /// Activate the mirroring window (FocusGuard). Throws mirroringNotRunning if not found.
    public static func activateAndFocus() async throws {
        do {
            try WindowManagement.activateWindow(titlePattern: "iPhone Mirroring")
        } catch {
            throw MCPError.mirroringNotRunning
        }
        // Brief delay to ensure window is fully focused
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }

    /// Check if the mirroring window is actively rendering (not blank/disconnected).
    public static func isConnected() -> Bool {
        guard let windowID = _cachedWindowID,
              let bounds = _cachedWindowBounds else {
            guard let (wid, wb) = try? findMirroringWindow() else { return false }
            return checkWindowHasContent(windowID: wid, bounds: wb)
        }
        return checkWindowHasContent(windowID: windowID, bounds: bounds)
    }

    private static func checkWindowHasContent(windowID: CGWindowID, bounds: CGRect) -> Bool {
        guard let image = CGWindowListCreateImage(
            bounds, .optionIncludingWindow, windowID, [.nominalResolution]
        ) else { return false }

        let width = image.width
        let height = image.height
        guard width > 10, height > 10 else { return false }

        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else { return false }

        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow

        // Sample 5 points — if all same color, likely disconnected
        let points = [(width/4, height/4), (width/2, height/2), (3*width/4, height/4),
                       (width/4, 3*height/4), (3*width/4, 3*height/4)]

        var firstR: UInt8 = 0, firstG: UInt8 = 0, firstB: UInt8 = 0
        for (i, (x, y)) in points.enumerated() {
            let offset = y * bytesPerRow + x * bytesPerPixel
            guard offset + 2 < CFDataGetLength(data) else { return false }
            let r = ptr[offset], g = ptr[offset + 1], b = ptr[offset + 2]
            if i == 0 { firstR = r; firstG = g; firstB = b }
            else if r != firstR || g != firstG || b != firstB { return true }
        }
        return false // All pixels same = disconnected
    }

    /// Clear cached window info.
    public static func clearCache() {
        _cachedWindowID = nil
        _cachedWindowBounds = nil
    }

    // MARK: - Private

    private static func windowArea(_ window: [String: Any]) -> CGFloat {
        guard let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat else {
            return 0
        }
        return width * height
    }
}
