import Foundation
@testable import MacOSControlLib

// STORY-010 — router double for SmartInteractTool surface tests.
final class FakeInteractionRouter: InteractionRouting {

    var stubbedResult = RouterResult(method: "ax_semantic", confidence: 0.95, decisionLog: [])
    private(set) var lastInput: SmartInteractInput?
    private(set) var routeCallCount = 0

    func route(input: SmartInteractInput) async -> RouterResult {
        routeCallCount += 1
        lastInput = input
        return stubbedResult
    }
}
