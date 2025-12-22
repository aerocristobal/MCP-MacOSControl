import Foundation
import CoreGraphics
import AppKit

class MouseControl {

    /// Click at the specified screen coordinates
    static func click(x: Int, y: Int) throws {
        let point = CGPoint(x: x, y: y)

        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)

        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
    }

    /// Move the mouse to the specified screen coordinates
    static func moveMouse(x: Int, y: Int) throws {
        let point = CGPoint(x: x, y: y)
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)
    }

    /// Hold down a mouse button
    static func mouseDown(button: String = "left") throws {
        let currentLocation = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let cgPoint = CGPoint(x: currentLocation.x, y: screenHeight - currentLocation.y)

        let (mouseType, mouseButton) = try getMouseTypeAndButton(button: button, isDown: true)
        let event = CGEvent(mouseEventSource: nil, mouseType: mouseType, mouseCursorPosition: cgPoint, mouseButton: mouseButton)
        event?.post(tap: .cghidEventTap)
    }

    /// Release a mouse button
    static func mouseUp(button: String = "left") throws {
        let currentLocation = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let cgPoint = CGPoint(x: currentLocation.x, y: screenHeight - currentLocation.y)

        let (mouseType, mouseButton) = try getMouseTypeAndButton(button: button, isDown: false)
        let event = CGEvent(mouseEventSource: nil, mouseType: mouseType, mouseCursorPosition: cgPoint, mouseButton: mouseButton)
        event?.post(tap: .cghidEventTap)
    }

    /// Drag the mouse from one position to another
    static func dragMouse(fromX: Int, fromY: Int, toX: Int, toY: Int, duration: Double = 0.5) async throws {
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
    static func getScreenSize() -> (width: Int, height: Int) {
        guard let screen = NSScreen.main else {
            return (width: 0, height: 0)
        }
        let frame = screen.frame
        return (width: Int(frame.width), height: Int(frame.height))
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
