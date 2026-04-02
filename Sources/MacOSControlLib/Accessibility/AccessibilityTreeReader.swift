import Foundation
import AppKit

public enum AccessibilityTreeReader {

    /// Read the accessibility tree for an application.
    public static func readTree(appName: String? = nil, windowTitle: String? = nil, maxDepth: Int = 3) throws -> [String: Any] {
        // Check permission
        guard AXIsProcessTrusted() else {
            throw MCPError.permissionDenied("Accessibility permission required. Go to System Settings > Privacy & Security > Accessibility and enable permission for the app running this MCP server.")
        }

        // Find the target application
        let runningApps = NSWorkspace.shared.runningApplications

        let targetApp: NSRunningApplication?
        if let appName = appName {
            targetApp = runningApps.first { app in
                app.localizedName?.localizedCaseInsensitiveContains(appName) == true
            }
        } else {
            // Use frontmost app if no name specified
            targetApp = NSWorkspace.shared.frontmostApplication
        }

        guard let app = targetApp else {
            throw MCPError.windowNotFound("Application '\(appName ?? "frontmost")' not found")
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // If window title specified, find that specific window
        if let windowTitle = windowTitle {
            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
            guard result == .success, let windows = windowsRef as? [AXUIElement] else {
                throw MCPError.windowNotFound("Could not access windows for '\(app.localizedName ?? "unknown")'")
            }

            for window in windows {
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
                if let title = titleRef as? String, title.localizedCaseInsensitiveContains(windowTitle) {
                    return readElement(window, depth: 0, maxDepth: maxDepth)
                }
            }

            throw MCPError.windowNotFound("Window titled '\(windowTitle)' not found in '\(app.localizedName ?? "unknown")'")
        }

        // Return the full app tree
        return readElement(appElement, depth: 0, maxDepth: maxDepth)
    }

    // MARK: - Private

    private static func readElement(_ element: AXUIElement, depth: Int, maxDepth: Int) -> [String: Any] {
        var node: [String: Any] = [:]

        // Role
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String {
            node["role"] = role
        }

        // Title / Label
        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success,
           let title = titleRef as? String, !title.isEmpty {
            node["title"] = title
        }

        // Description (often used as label)
        var descRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
           let desc = descRef as? String, !desc.isEmpty {
            node["description"] = desc
        }

        // Value
        var valueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success {
            if let stringValue = valueRef as? String {
                node["value"] = stringValue
            } else if let numberValue = valueRef as? NSNumber {
                node["value"] = numberValue
            }
        }

        // Position
        var positionRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success {
            var point = CGPoint.zero
            if AXValueGetValue(positionRef as! AXValue, .cgPoint, &point) {
                node["position"] = ["x": Int(point.x), "y": Int(point.y)]
            }
        }

        // Size
        var sizeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success {
            var size = CGSize.zero
            if AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) {
                node["size"] = ["width": Int(size.width), "height": Int(size.height)]
            }
        }

        // Children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            if depth < maxDepth {
                node["children"] = children.map { readElement($0, depth: depth + 1, maxDepth: maxDepth) }
            } else {
                node["childCount"] = children.count
            }
        }

        return node
    }
}
