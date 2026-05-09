import Foundation
import AppKit
import ApplicationServices

public protocol AXApplicationBridge {
    func runningApplications() -> [(pid: pid_t, bundleId: String?, name: String?)]
    func windows(forPID pid: pid_t) throws -> [AXElementReference]
    func attribute(_ kind: AXAttributeKind, of ref: AXElementReference) -> String?
    func children(of ref: AXElementReference) throws -> [AXElementReference]
    func performAction(_ name: String, on ref: AXElementReference) throws
    func copyActionNames(_ ref: AXElementReference) throws -> [String]
    func isEnabled(_ ref: AXElementReference) -> Bool
    func value(of ref: AXElementReference) -> String?
}

public final class AXApplicationBridgeImpl: AXApplicationBridge {
    public init() {}

    public func runningApplications() -> [(pid: pid_t, bundleId: String?, name: String?)] {
        NSWorkspace.shared.runningApplications.map { app in
            (pid: app.processIdentifier, bundleId: app.bundleIdentifier, name: app.localizedName)
        }
    }

    public func windows(forPID pid: pid_t) throws -> [AXElementReference] {
        let app = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)

        switch result {
        case .success:
            break
        case .cannotComplete, .notImplemented, .invalidUIElement, .noValue, .attributeUnsupported:
            MCPLogger.debug("AX windows fetch returned \(result.rawValue) for pid \(pid); treating as empty")
            return []
        default:
            throw AXResolutionError(
                detail: "windows lookup failed for pid \(pid)",
                underlyingCode: result.rawValue
            )
        }

        guard let windows = windowsRef as? [AXUIElement] else { return [] }
        let runningApp = NSRunningApplication(processIdentifier: pid)
        let bundleId = runningApp?.bundleIdentifier
        return windows.map { window in
            buildReference(from: window, pid: pid, bundleId: bundleId)
        }
    }

    public func attribute(_ kind: AXAttributeKind, of ref: AXElementReference) -> String? {
        guard case .real(let element) = ref.handle else { return nil }
        var raw: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, axAttributeName(for: kind), &raw)
        guard status == .success else { return nil }
        return raw as? String
    }

    public func children(of ref: AXElementReference) throws -> [AXElementReference] {
        guard case .real(let element) = ref.handle else { return [] }
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        if result == .success, let kids = childrenRef as? [AXUIElement] {
            return kids.map { buildReference(from: $0, pid: ref.pid ?? 0, bundleId: ref.bundleId) }
        }
        return []
    }

    public func performAction(_ name: String, on ref: AXElementReference) throws {
        guard case .real(let element) = ref.handle else {
            throw AXResolutionError(detail: "cannot perform action on non-real element handle")
        }
        let status = AXUIElementPerformAction(element, name as CFString)
        guard status == .success else {
            throw AXResolutionError(
                detail: "perform action '\(name)' failed",
                underlyingCode: status.rawValue
            )
        }
    }

    public func copyActionNames(_ ref: AXElementReference) throws -> [String] {
        guard case .real(let element) = ref.handle else {
            throw AXResolutionError(detail: "cannot enumerate actions on non-real element handle")
        }
        var namesRef: CFArray?
        let status = AXUIElementCopyActionNames(element, &namesRef)
        switch status {
        case .success:
            return (namesRef as? [String]) ?? []
        case .noValue, .attributeUnsupported, .actionUnsupported:
            return []
        default:
            throw AXResolutionError(
                detail: "copy action names failed",
                underlyingCode: status.rawValue
            )
        }
    }

    public func isEnabled(_ ref: AXElementReference) -> Bool {
        guard case .real(let element) = ref.handle else { return true }
        var raw: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &raw)
        guard status == .success, let cfBool = raw, CFGetTypeID(cfBool) == CFBooleanGetTypeID() else {
            return true
        }
        return CFBooleanGetValue((cfBool as! CFBoolean))
    }

    public func value(of ref: AXElementReference) -> String? {
        guard case .real(let element) = ref.handle else { return nil }
        var raw: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &raw)
        guard status == .success, let value = raw else { return nil }
        if CFGetTypeID(value) == CFBooleanGetTypeID() {
            return CFBooleanGetValue((value as! CFBoolean)) ? "1" : "0"
        }
        if let s = value as? String { return s.isEmpty ? nil : s }
        if let n = value as? NSNumber { return n.stringValue }
        return nil
    }

    private func buildReference(from element: AXUIElement, pid: pid_t, bundleId: String?) -> AXElementReference {
        AXElementReference(
            role: copyStringAttribute(element, kAXRoleAttribute as CFString),
            title: copyStringAttribute(element, kAXTitleAttribute as CFString),
            identifier: copyStringAttribute(element, kAXIdentifierAttribute as CFString),
            label: copyStringAttribute(element, "AXLabel" as CFString),
            description: copyStringAttribute(element, kAXDescriptionAttribute as CFString),
            pid: pid,
            bundleId: bundleId,
            handle: .real(element)
        )
    }

    private func copyStringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var ref: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &ref)
        guard status == .success else { return nil }
        let value = ref as? String
        return (value?.isEmpty == true) ? nil : value
    }

    private func axAttributeName(for kind: AXAttributeKind) -> CFString {
        switch kind {
        case .role: return kAXRoleAttribute as CFString
        case .title: return kAXTitleAttribute as CFString
        case .identifier: return kAXIdentifierAttribute as CFString
        case .label: return "AXLabel" as CFString
        case .description: return kAXDescriptionAttribute as CFString
        }
    }
}
