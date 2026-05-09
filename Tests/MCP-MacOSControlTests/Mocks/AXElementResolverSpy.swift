import Foundation
@testable import MacOSControlLib

final class AXElementResolverSpy: AXElementResolving {
    var stubbedResult: AXElementReference?
    var stubbedError: Error?

    var callCount: Int = 0
    var lastRole: String?
    var lastTitle: String?
    var lastIdentifier: String?
    var lastLabel: String?
    var lastDescription: String?
    var lastAttributeKind: AXAttributeKind?
    var lastAttributeValue: String?
    var lastScope: AXResolverScope?

    func findElement(
        role: String?,
        title: String?,
        scope: AXResolverScope?
    ) throws -> AXElementReference {
        callCount += 1
        lastRole = role
        lastTitle = title
        lastScope = scope
        if let err = stubbedError { throw err }
        guard let ref = stubbedResult else {
            throw AXNotFoundError(searchCriteria: "spy: no stub configured")
        }
        return ref
    }

    func findElement(
        by kind: AXAttributeKind,
        value: String,
        scope: AXResolverScope?
    ) throws -> AXElementReference {
        callCount += 1
        lastAttributeKind = kind
        lastAttributeValue = value
        lastScope = scope
        switch kind {
        case .role: lastRole = value
        case .title: lastTitle = value
        case .identifier: lastIdentifier = value
        case .label: lastLabel = value
        case .description: lastDescription = value
        }
        if let err = stubbedError { throw err }
        guard let ref = stubbedResult else {
            throw AXNotFoundError(searchCriteria: "spy: no stub configured")
        }
        return ref
    }
}

extension AXElementReference {
    static func mockReference(
        role: String? = nil,
        title: String? = nil,
        identifier: String? = nil,
        label: String? = nil,
        description: String? = nil,
        pid: pid_t? = nil,
        bundleId: String? = nil
    ) -> AXElementReference {
        AXElementReference(
            role: role,
            title: title,
            identifier: identifier,
            label: label,
            description: description,
            pid: pid,
            bundleId: bundleId,
            handle: .mock(UUID())
        )
    }
}
