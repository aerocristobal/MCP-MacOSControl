import Foundation
import ApplicationServices
@testable import MacOSControlLib

final class MockAXApplicationBridge: AXApplicationBridge {
    let elements: [MockAXUIElement]
    let simulatedAXError: AXError?
    private var refToMock: [UUID: MockAXUIElement] = [:]

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
        // Not exercised in STORY-001 tests.
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
