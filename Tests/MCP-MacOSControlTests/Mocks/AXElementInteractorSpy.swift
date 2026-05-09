import Foundation
@testable import MacOSControlLib

final class AXElementInteractorSpy: AXElementInteracting {
    var simulatedError: Error?
    var pressCallCount: Int = 0
    var lastPressedElement: AXElementReference?

    func performPress(_ ref: AXElementReference) throws {
        pressCallCount += 1
        lastPressedElement = ref
        if let err = simulatedError { throw err }
    }
}
