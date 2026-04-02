import Foundation
import CoreGraphics

public enum GestureEngine {
    /// Single tap at normalized coordinates.
    public static func tap(x: Double, y: Double) async throws {
        try await MirroringWindowDetector.activateAndFocus()
        let point = try await CoordinateTranslator.toAbsolute(normalizedX: x, normalizedY: y)
        try MouseControl.click(x: Int(point.x), y: Int(point.y))
    }

    /// Double tap at normalized coordinates (two clicks with 50ms gap).
    public static func doubleTap(x: Double, y: Double) async throws {
        try await MirroringWindowDetector.activateAndFocus()
        let point = try await CoordinateTranslator.toAbsolute(normalizedX: x, normalizedY: y)
        try MouseControl.click(x: Int(point.x), y: Int(point.y))
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        try MouseControl.click(x: Int(point.x), y: Int(point.y))
    }

    /// Long press at normalized coordinates with configurable duration.
    public static func longPress(x: Double, y: Double, duration: Double = 1.0) async throws {
        try await MirroringWindowDetector.activateAndFocus()
        let point = try await CoordinateTranslator.toAbsolute(normalizedX: x, normalizedY: y)

        // Move mouse to position first
        try MouseControl.moveMouse(x: Int(point.x), y: Int(point.y))

        // Mouse down
        try MouseControl.mouseDown(button: "left")

        // Hold for duration
        let nanoseconds = UInt64(duration * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)

        // Mouse up
        try MouseControl.mouseUp(button: "left")
    }

    /// Swipe from start to end coordinates with ease-in-out curve and initial nudge.
    /// All coordinates normalized 0-1. Duration in seconds.
    public static func swipe(
        startX: Double, startY: Double,
        endX: Double, endY: Double,
        duration: Double = 0.5
    ) async throws {
        try await MirroringWindowDetector.activateAndFocus()

        let startPoint = try await CoordinateTranslator.toAbsolute(normalizedX: startX, normalizedY: startY)
        let endPoint = try await CoordinateTranslator.toAbsolute(normalizedX: endX, normalizedY: endY)

        let startXInt = Int(startPoint.x)
        let startYInt = Int(startPoint.y)
        let endXInt = Int(endPoint.x)
        let endYInt = Int(endPoint.y)

        // Calculate swipe direction for nudge
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let distance = sqrt(dx * dx + dy * dy)
        guard distance > 0 else { return }

        // Normalize direction
        let ndx = dx / distance
        let ndy = dy / distance

        // Move to start position
        try MouseControl.moveMouse(x: startXInt, y: startYInt)

        // Mouse down at start
        try MouseControl.mouseDown(button: "left")

        // Initial nudge: small 2px movement in swipe direction + pause
        let nudgeX = startXInt + Int(ndx * 2)
        let nudgeY = startYInt + Int(ndy * 2)

        if let nudgeEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged,
                                     mouseCursorPosition: CGPoint(x: nudgeX, y: nudgeY),
                                     mouseButton: .left) {
            nudgeEvent.post(tap: .cghidEventTap)
        }
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms pause after nudge

        // Smooth drag with ease-in-out curve
        let steps = 60
        let stepDuration = duration / Double(steps)

        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let easedT = easeInOut(t)

            let currentX = startPoint.x + (endPoint.x - startPoint.x) * CGFloat(easedT)
            let currentY = startPoint.y + (endPoint.y - startPoint.y) * CGFloat(easedT)

            if let dragEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged,
                                        mouseCursorPosition: CGPoint(x: currentX, y: currentY),
                                        mouseButton: .left) {
                dragEvent.post(tap: .cghidEventTap)
            }

            try await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
        }

        // Mouse up at end
        try MouseControl.mouseUp(button: "left")
    }

    /// Scroll at the center of the content rect.
    public static func scroll(deltaX: Int32 = 0, deltaY: Int32 = 0) async throws {
        try await MirroringWindowDetector.activateAndFocus()

        let contentRect = try await CoordinateTranslator.getContentRect()
        let centerX = contentRect.midX
        let centerY = contentRect.midY

        // Move mouse to center of content area
        try MouseControl.moveMouse(x: Int(centerX), y: Int(centerY))

        // Post scroll wheel event
        if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                      wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0) {
            scrollEvent.location = CGPoint(x: centerX, y: centerY)
            scrollEvent.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Internal (visible for testing)

    /// Ease-in-out interpolation: t² × (3 - 2t)
    public static func easeInOut(_ t: Double) -> Double {
        return t * t * (3.0 - 2.0 * t)
    }
}
