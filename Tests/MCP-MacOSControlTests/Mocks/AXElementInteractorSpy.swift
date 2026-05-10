import Foundation
@testable import MacOSControlLib

final class AXElementInteractorSpy: AXElementInteracting {
    var simulatedError: Error?
    var pressCallCount: Int = 0
    var lastPressedElement: AXElementReference?

    var performCallCount: Int = 0
    var lastAction: String?
    var lastPerformedElement: AXElementReference?
    var performedActions: [String] = []

    func performPress(_ ref: AXElementReference) throws {
        pressCallCount += 1
        lastPressedElement = ref
        if let err = simulatedError { throw err }
    }

    func perform(_ action: String, on ref: AXElementReference) throws {
        performCallCount += 1
        lastAction = action
        lastPerformedElement = ref
        performedActions.append(action)
        if let err = simulatedError { throw err }
    }

    func reset() {
        simulatedError = nil
        pressCallCount = 0
        lastPressedElement = nil
        performCallCount = 0
        lastAction = nil
        lastPerformedElement = nil
        performedActions = []
    }
}
