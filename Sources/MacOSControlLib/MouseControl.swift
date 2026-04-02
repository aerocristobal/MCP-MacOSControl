import Foundation
import CoreGraphics
import AppKit

public class MouseControl {

    /// Click at the specified screen coordinates
    public static func click(x: Int, y: Int) throws {
        let point = CGPoint(x: x, y: y)

        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)

        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
    }

    /// Move the mouse to the specified screen coordinates
    public static func moveMouse(x: Int, y: Int) throws {
        let point = CGPoint(x: x, y: y)
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)
    }

    /// Hold down a mouse button
    public static func mouseDown(button: String = "left") throws {
        let currentLocation = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let cgPoint = CGPoint(x: currentLocation.x, y: screenHeight - currentLocation.y)

        let (mouseType, mouseButton) = try getMouseTypeAndButton(button: button, isDown: true)
        let event = CGEvent(mouseEventSource: nil, mouseType: mouseType, mouseCursorPosition: cgPoint, mouseButton: mouseButton)
        event?.post(tap: .cghidEventTap)
    }

    /// Release a mouse button
    public static func mouseUp(button: String = "left") throws {
        let currentLocation = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let cgPoint = CGPoint(x: currentLocation.x, y: screenHeight - currentLocation.y)

        let (mouseType, mouseButton) = try getMouseTypeAndButton(button: button, isDown: false)
        let event = CGEvent(mouseEventSource: nil, mouseType: mouseType, mouseCursorPosition: cgPoint, mouseButton: mouseButton)
        event?.post(tap: .cghidEventTap)
    }

    /// Drag the mouse from one position to another
    public static func dragMouse(fromX: Int, fromY: Int, toX: Int, toY: Int, duration: Double = 0.5) async throws {
        // Move to start position
        try moveMouse(x: fromX, y: fromY)
        try await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000))

        // Press mouse down
        let startPoint = CGPoint(x: fromX, y: fromY)
        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: startPoint, mouseButton: .left)
        mouseDown?.post(tap: .cghidEventTap)

        // Calculate steps for smooth drag
        let steps = max(Int(duration * 60), 10) // 60 steps per second
        let deltaX = Double(toX - fromX) / Double(steps)
        let deltaY = Double(toY - fromY) / Double(steps)
        let sleepNanos = UInt64((duration / Double(steps)) * 1_000_000_000)

        // Perform drag
        for i in 1...steps {
            let currentX = Double(fromX) + deltaX * Double(i)
            let currentY = Double(fromY) + deltaY * Double(i)
            let currentPoint = CGPoint(x: currentX, y: currentY)

            let dragEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: currentPoint, mouseButton: .left)
            dragEvent?.post(tap: .cghidEventTap)

            try await Task.sleep(nanoseconds: sleepNanos)
        }

        // Release mouse
        let endPoint = CGPoint(x: toX, y: toY)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: endPoint, mouseButton: .left)
        mouseUp?.post(tap: .cghidEventTap)
    }

    /// Get the current screen size
    public static func getScreenSize() -> (width: Int, height: Int) {
        guard let screen = NSScreen.main else {
            return (width: 0, height: 0)
        }
        let frame = screen.frame
        return (width: Int(frame.width), height: Int(frame.height))
    }

    /// Click with configurable button at screen coordinates
    public static func click(x: Int, y: Int, button: String) throws {
        let point = CGPoint(x: x, y: y)
        let (downType, mouseButton) = try getMouseTypeAndButton(button: button, isDown: true)
        let (upType, _) = try getMouseTypeAndButton(button: button, isDown: false)

        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: point, mouseButton: mouseButton)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: point, mouseButton: mouseButton)

        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
    }

    /// Double-click at the specified screen coordinates
    public static func doubleClick(x: Int, y: Int) throws {
        let point = CGPoint(x: x, y: y)

        // First click
        let down1 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        down1?.setIntegerValueField(.mouseEventClickState, value: 1)
        down1?.post(tap: .cghidEventTap)

        let up1 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        up1?.setIntegerValueField(.mouseEventClickState, value: 1)
        up1?.post(tap: .cghidEventTap)

        // Brief delay
        usleep(50000) // 50ms

        // Second click with clickState=2
        let down2 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        down2?.setIntegerValueField(.mouseEventClickState, value: 2)
        down2?.post(tap: .cghidEventTap)

        let up2 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        up2?.setIntegerValueField(.mouseEventClickState, value: 2)
        up2?.post(tap: .cghidEventTap)
    }

    /// Scroll at the specified screen coordinates
    public static func scroll(x: Int? = nil, y: Int? = nil, direction: String, amount: Int = 3) throws {
        // Move to position if specified
        if let x = x, let y = y {
            try moveMouse(x: x, y: y)
        }

        var wheel1: Int32 = 0
        var wheel2: Int32 = 0

        switch direction.lowercased() {
        case "up":
            wheel1 = -Int32(amount)
        case "down":
            wheel1 = Int32(amount)
        case "left":
            wheel2 = -Int32(amount)
        case "right":
            wheel2 = Int32(amount)
        default:
            throw NSError(domain: "MouseControl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid direction: \(direction). Must be up, down, left, or right"])
        }

        if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .line,
                                      wheelCount: 2, wheel1: wheel1, wheel2: wheel2, wheel3: 0) {
            scrollEvent.post(tap: .cghidEventTap)
        }
    }

    /// List all connected displays with their properties
    public static func listDisplays() -> [[String: Any]] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)

        let mainDisplay = CGMainDisplayID()

        return displays.map { displayID in
            let bounds = CGDisplayBounds(displayID)
            let pixelWidth = CGDisplayPixelsWide(displayID)
            let pixelHeight = CGDisplayPixelsHigh(displayID)
            let scaleFactor = bounds.width > 0 ? Double(pixelWidth) / Double(bounds.width) : 1.0

            return [
                "displayId": displayID,
                "width": Int(bounds.width),
                "height": Int(bounds.height),
                "pixelWidth": pixelWidth,
                "pixelHeight": pixelHeight,
                "originX": Int(bounds.origin.x),
                "originY": Int(bounds.origin.y),
                "scaleFactor": scaleFactor,
                "isMain": displayID == mainDisplay
            ] as [String: Any]
        }
    }

    // Helper function to convert button string to CGEventType and CGMouseButton
    private static func getMouseTypeAndButton(button: String, isDown: Bool) throws -> (CGEventType, CGMouseButton) {
        switch button.lowercased() {
        case "left":
            return (isDown ? .leftMouseDown : .leftMouseUp, .left)
        case "right":
            return (isDown ? .rightMouseDown : .rightMouseUp, .right)
        case "middle":
            return (isDown ? .otherMouseDown : .otherMouseUp, .center)
        default:
            throw NSError(domain: "MouseControl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid button type: \(button)"])
        }
    }
}
