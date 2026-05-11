import Foundation
import CoreGraphics
import ApplicationServices
@testable import MacOSControlLib

final class MockAXApplicationBridge: AXApplicationBridge {
    let elements: [MockAXUIElement]
    var simulatedAXError: AXError?
    private var refToMock: [UUID: MockAXUIElement] = [:]

    var lastPerformedAction: String?
    var lastTargetElement: AXElementReference?
    var performActionCallCount: Int = 0

    var copyActionNamesCallCount: Int = 0
    var lastCopyActionNamesElement: AXElementReference?
    /// Override the per-element supported-action list keyed by handle UUID. Falls back to the
    /// `supportedActions` field on the underlying `MockAXUIElement` when no override exists.
    var elementActions: [UUID: [String]] = [:]

    /// Per-PID application root element. When set, `applicationRoot(forPID:)` returns this.
    /// Allows tests to drive the tree builder from a synthetic application root.
    var applicationRoots: [pid_t: MockAXUIElement] = [:]

    var hitTestCallCount: Int = 0
    var lastHitTestX: CGFloat?
    var lastHitTestY: CGFloat?
    /// Element returned by `copyElementAtPosition`. nil → simulate empty hit.
    var stubbedHitTestResult: MockAXUIElement?
    /// When set, `copyElementAtPosition` throws this instead of returning.
    var stubbedHitTestError: Error?

    init(elements: [MockAXUIElement] = [], simulatedAXError: AXError? = nil) {
        self.elements = elements
        self.simulatedAXError = simulatedAXError
    }

    func runningApplications() -> [(pid: pid_t, bundleId: String?, name: String?)] {
        if simulatedAXError != nil && elements.isEmpty {
            return [(pid: 9999, bundleId: nil, name: nil)]
        }
        var seen: [pid_t: (bundleId: String?, name: String?)] = [:]
        var ordered: [pid_t] = []
        for element in elements {
            if seen[element.pid] == nil {
                seen[element.pid] = (bundleId: element.bundleId, name: nil)
                ordered.append(element.pid)
            }
        }
        return ordered.map { pid in
            let info = seen[pid]
            return (pid: pid, bundleId: info?.bundleId, name: info?.name)
        }
    }

    func windows(forPID pid: pid_t) throws -> [AXElementReference] {
        if let err = simulatedAXError {
            throw AXResolutionError(
                detail: "simulated AX error \(err.rawValue)",
                underlyingCode: err.rawValue
            )
        }
        return elements
            .filter { $0.pid == pid }
            .map { reference(for: $0) }
    }

    func attribute(_ kind: AXAttributeKind, of ref: AXElementReference) -> String? {
        switch kind {
        case .role: return ref.role
        case .title: return ref.title
        case .identifier: return ref.identifier
        case .label: return ref.label
        case .description: return ref.description
        }
    }

    func children(of ref: AXElementReference) throws -> [AXElementReference] {
        if let err = simulatedAXError {
            throw AXResolutionError(
                detail: "simulated AX error \(err.rawValue)",
                underlyingCode: err.rawValue
            )
        }
        guard case .mock(let id) = ref.handle, let mock = refToMock[id] else { return [] }
        return mock.children.map { reference(for: $0) }
    }

    func performAction(_ name: String, on ref: AXElementReference) throws {
        performActionCallCount += 1
        lastPerformedAction = name
        lastTargetElement = ref
        if let err = simulatedAXError {
            throw AXResolutionError(
                detail: "simulated AX error \(err.rawValue) on action '\(name)'",
                underlyingCode: err.rawValue
            )
        }
    }

    func copyActionNames(_ ref: AXElementReference) throws -> [String] {
        copyActionNamesCallCount += 1
        lastCopyActionNamesElement = ref
        if let err = simulatedAXError {
            throw AXResolutionError(
                detail: "simulated AX error \(err.rawValue) on copyActionNames",
                underlyingCode: err.rawValue
            )
        }
        guard case .mock(let id) = ref.handle else { return [] }
        if let override = elementActions[id] { return override }
        return refToMock[id]?.supportedActions ?? []
    }

    func isEnabled(_ ref: AXElementReference) -> Bool {
        guard case .mock(let id) = ref.handle, let mock = refToMock[id] else { return true }
        return mock.enabled
    }

    func value(of ref: AXElementReference) -> String? {
        guard case .mock(let id) = ref.handle, let mock = refToMock[id] else { return nil }
        return mock.value
    }

    func applicationRoot(forPID pid: pid_t) -> AXElementReference? {
        guard let mock = applicationRoots[pid] else { return nil }
        return reference(for: mock)
    }

    func position(of ref: AXElementReference) -> CGPoint? {
        guard case .mock(let id) = ref.handle, let mock = refToMock[id] else { return nil }
        return mock.position
    }

    func size(of ref: AXElementReference) -> CGSize? {
        guard case .mock(let id) = ref.handle, let mock = refToMock[id] else { return nil }
        return mock.size
    }

    func isEnabledSupported(_ ref: AXElementReference) -> Bool {
        guard case .mock(let id) = ref.handle, let mock = refToMock[id] else { return false }
        return mock.enabledSupported
    }

    func isValueSettable(_ ref: AXElementReference) -> Bool {
        guard case .mock(let id) = ref.handle, let mock = refToMock[id] else { return false }
        return mock.valueSettable
    }

    func rawValue(of ref: AXElementReference) -> AXNodeValue? {
        guard case .mock(let id) = ref.handle, let mock = refToMock[id] else { return nil }
        if let raw = mock.rawValue { return raw }
        if let s = mock.value { return .string(s) }
        return nil
    }

    // MARK: - STORY-015: Extended state attributes

    func isFocused(_ ref: AXElementReference) -> Bool? {
        guard case .mock(let id) = ref.handle, let mock = refToMock[id] else { return nil }
        return mock.focused
    }

    func isSelected(_ ref: AXElementReference) -> Bool? {
        guard let role = ref.role,
              AXApplicationBridgeImpl.selectableRoles.contains(role) else { return nil }
        guard case .mock(let id) = ref.handle, let mock = refToMock[id] else { return nil }
        return mock.selected
    }

    func isExpanded(_ ref: AXElementReference) -> Bool? {
        guard case .mock(let id) = ref.handle, let mock = refToMock[id] else { return nil }
        return mock.expanded
    }

    func isMain(_ ref: AXElementReference) -> Bool? {
        guard ref.role == "AXWindow" else { return nil }
        guard case .mock(let id) = ref.handle, let mock = refToMock[id] else { return nil }
        return mock.isMain
    }

    func isMinimized(_ ref: AXElementReference) -> Bool? {
        guard ref.role == "AXWindow" else { return nil }
        guard case .mock(let id) = ref.handle, let mock = refToMock[id] else { return nil }
        return mock.isMinimized
    }

    func isFrontmost(_ ref: AXElementReference) -> Bool? {
        guard ref.role == "AXWindow" else { return nil }
        guard case .mock(let id) = ref.handle, let mock = refToMock[id] else { return nil }
        return mock.isFrontmost
    }

    func frame(of ref: AXElementReference) -> CGRect? {
        guard case .mock(let id) = ref.handle, let mock = refToMock[id] else { return nil }
        if let f = mock.frame { return f }
        if let pos = mock.position, let sz = mock.size {
            return CGRect(origin: pos, size: sz)
        }
        return nil
    }

    func copyElementAtPosition(globalX: CGFloat, globalY: CGFloat) throws -> AXElementReference? {
        hitTestCallCount += 1
        lastHitTestX = globalX
        lastHitTestY = globalY
        if let err = stubbedHitTestError { throw err }
        return stubbedHitTestResult.map { reference(for: $0) }
    }

    private func reference(for mock: MockAXUIElement) -> AXElementReference {
        let id = UUID()
        refToMock[id] = mock
        return AXElementReference(
            role: mock.role,
            title: mock.title,
            identifier: mock.identifier,
            label: mock.label,
            description: mock.description,
            pid: mock.pid,
            bundleId: mock.bundleId,
            handle: .mock(id)
        )
    }
}
