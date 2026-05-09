import Foundation
import AppKit
import ApplicationServices

public final class AXElementResolver {
    private let bridge: AXApplicationBridge
    private let options: AXResolverOptions

    public init(bridge: AXApplicationBridge, options: AXResolverOptions = .init()) {
        self.bridge = bridge
        self.options = options
    }

    public func findElement(
        role: String?,
        title: String?,
        scope: AXResolverScope?
    ) throws -> AXElementReference {
        let criteria = describeCriteria(role: role, title: title, scope: scope)
        let pids = pidsInScope(scope)
        let deadline = Date().addingTimeInterval(options.timeout)

        for pid in pids {
            for window in try bridge.windows(forPID: pid) {
                if let match = try search(
                    in: window,
                    role: role,
                    title: title,
                    depth: 0,
                    deadline: deadline
                ) {
                    return match
                }
            }
        }

        throw AXNotFoundError(searchCriteria: criteria)
    }

    public func findElement(
        by kind: AXAttributeKind,
        value: String,
        scope: AXResolverScope? = nil
    ) throws -> AXElementReference {
        let criteria = describeCriteria(attribute: kind, value: value, scope: scope)
        let pids = pidsInScope(scope)
        let deadline = Date().addingTimeInterval(options.timeout)

        for pid in pids {
            for window in try bridge.windows(forPID: pid) {
                if let match = try search(
                    in: window,
                    attribute: kind,
                    value: value,
                    depth: 0,
                    deadline: deadline
                ) {
                    return match
                }
            }
        }

        throw AXNotFoundError(searchCriteria: criteria)
    }

    private func pidsInScope(_ scope: AXResolverScope?) -> [pid_t] {
        let apps = bridge.runningApplications()
        switch scope {
        case .none:
            return apps.map { $0.pid }
        case .pid(let p):
            return apps.contains(where: { $0.pid == p }) ? [p] : []
        case .bundleId(let bid):
            return apps.filter { $0.bundleId == bid }.map { $0.pid }
        case .name(let n):
            return apps.filter { ($0.name ?? "").localizedCaseInsensitiveContains(n) }.map { $0.pid }
        }
    }

    private func search(
        in element: AXElementReference,
        role: String?,
        title: String?,
        depth: Int,
        deadline: Date
    ) throws -> AXElementReference? {
        if Date() > deadline {
            throw AXResolutionError(detail: "search exceeded timeout of \(options.timeout)s")
        }
        if matches(element, role: role, title: title) {
            return element
        }
        if depth >= options.maxDepth {
            return nil
        }
        for child in try bridge.children(of: element) {
            if let found = try search(
                in: child,
                role: role,
                title: title,
                depth: depth + 1,
                deadline: deadline
            ) {
                return found
            }
        }
        return nil
    }

    private func search(
        in element: AXElementReference,
        attribute: AXAttributeKind,
        value: String,
        depth: Int,
        deadline: Date
    ) throws -> AXElementReference? {
        if Date() > deadline {
            throw AXResolutionError(detail: "search exceeded timeout of \(options.timeout)s")
        }
        if matches(element, attribute: attribute, value: value) {
            return element
        }
        if depth >= options.maxDepth {
            return nil
        }
        for child in try bridge.children(of: element) {
            if let found = try search(
                in: child,
                attribute: attribute,
                value: value,
                depth: depth + 1,
                deadline: deadline
            ) {
                return found
            }
        }
        return nil
    }

    private func matches(_ element: AXElementReference, role: String?, title: String?) -> Bool {
        guard role != nil || title != nil else { return false }
        if let r = role, element.role != r { return false }
        if let t = title, element.title != t { return false }
        return true
    }

    private func matches(_ element: AXElementReference, attribute: AXAttributeKind, value: String) -> Bool {
        switch attribute {
        case .role: return element.role == value
        case .title: return element.title == value
        case .identifier: return element.identifier == value
        case .label: return element.label == value
        case .description: return element.description == value
        }
    }

    private func describeCriteria(role: String?, title: String?, scope: AXResolverScope?) -> String {
        var parts: [String] = []
        if let r = role { parts.append("role=\(r)") }
        if let t = title { parts.append("title=\(t)") }
        if let s = scope { parts.append("scope=\(describeScope(s))") }
        return parts.isEmpty ? "(no criteria)" : parts.joined(separator: ", ")
    }

    private func describeCriteria(attribute: AXAttributeKind, value: String, scope: AXResolverScope?) -> String {
        var parts = ["\(attribute.rawValue)=\(value)"]
        if let s = scope { parts.append("scope=\(describeScope(s))") }
        return parts.joined(separator: ", ")
    }

    private func describeScope(_ scope: AXResolverScope) -> String {
        switch scope {
        case .pid(let p): return "pid:\(p)"
        case .bundleId(let b): return "bundleId:\(b)"
        case .name(let n): return "name:\(n)"
        }
    }
}
