import Foundation
@testable import MacOSControlLib

final class AXActionEnumeratorSpy: AXActionEnumerating {
    var stubbedActions: [String] = []
    var stubbedError: Error?
    var callCount: Int = 0
    var lastElement: AXElementReference?

    func actionNames(for ref: AXElementReference) throws -> [String] {
        callCount += 1
        lastElement = ref
        if let err = stubbedError { throw err }
        return stubbedActions
    }
}
