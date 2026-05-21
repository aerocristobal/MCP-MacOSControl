// STORY-027 — Cancellation behaviour of InteractionRouter (smart_interact's
// four-layer fallback chain).
//
// Verifies that:
//   * cancellation between layer attempts halts the loop with a .cancelled
//     decision log entry for the layer that would have been tried next,
//   * cancellation mid-attempt (surfaced by a layer as .failed("cancelled"))
//     stops the loop and writes the decision log up to that point,
//   * remaining layers are NOT invoked after cancellation.

import XCTest
@testable import MacOSControlLib

final class InteractionRouterCancellationTests: XCTestCase {

    private let registry = StubCapabilityQuerying()

    private func input(_ intent: InteractionIntent = .click) -> SmartInteractInput {
        SmartInteractInput(
            intent: intent,
            targetDescription: "Submit",
            application: "TestApp",
            coordinates: nil,
            value: nil,
            skipLayers: []
        )
    }

    func test_cancellationBetweenLayers_stopsLoop_withCancelledDecisionEntry() async {
        let ax = FakeInteractionLayer(name: "ax_semantic")
        let applescript = FakeInteractionLayer(name: "applescript")
        let hitTest = FakeInteractionLayer(name: "ax_hit_test")
        ax.stubbedOutcome = .skipped(reason: "no AXAction")
        applescript.stubbedOutcome = .succeeded(method: "applescript", confidence: 0.85)

        let token = CancellationToken()
        let context = ToolCallContext(requestId: "req", cancellation: token)

        // Cancel WHILE the AX layer's attempt is in flight. The router's
        // between-layer check on the next iteration sees the cancellation
        // BEFORE AppleScript is touched.
        let cancellingAX = ObservingLayer(wrapped: ax, beforeAttempt: { token.cancel() })

        let router = InteractionRouter(
            layers: [cancellingAX, applescript, hitTest],
            registry: registry
        )

        let result = await router.route(input: input(), context: context)

        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "cancelled")
        XCTAssertEqual(applescript.callCount, 0, "AppleScript layer must not be invoked after cancellation")
        XCTAssertEqual(hitTest.callCount, 0, "later layers must not be invoked after cancellation")
        XCTAssertTrue(result.decisionLog.contains(where: { $0.outcome == .cancelled }),
                      "decision log must mark a .cancelled entry")
        // The first entry records the AX layer that ran (a .skipped attempt
        // that completed before cancellation propagated); the second entry is
        // the AppleScript layer that was abandoned with a .cancelled outcome.
        XCTAssertEqual(result.decisionLog.count, 2)
        XCTAssertEqual(result.decisionLog[1].layer, "applescript")
        XCTAssertEqual(result.decisionLog[1].outcome, .cancelled)
    }

    func test_cancellationMidLayerAttempt_recordsCancelledAndStopsLoop() async {
        let ax = FakeInteractionLayer(name: "ax_semantic")
        let applescript = FakeInteractionLayer(name: "applescript")
        let hitTest = FakeInteractionLayer(name: "ax_hit_test")
        let coordinate = FakeInteractionLayer(name: "coordinate_fallback")
        ax.stubbedOutcome = .skipped(reason: "no AXAction")
        // AppleScript layer simulates 200ms of work; we cancel during that work.
        applescript.simulatedDelayNanoseconds = 200_000_000
        applescript.stubbedOutcome = .succeeded(method: "applescript", confidence: 0.85)

        let token = CancellationToken()
        let context = ToolCallContext(requestId: "req", cancellation: token)

        let router = InteractionRouter(
            layers: [ax, applescript, hitTest, coordinate],
            registry: registry
        )

        let task = Task { await router.route(input: input(), context: context) }
        try? await Task.sleep(nanoseconds: 80_000_000) // partway through AppleScript
        token.cancel()
        let result = await task.value

        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "cancelled")
        XCTAssertEqual(applescript.callCount, 1, "AppleScript layer was mid-attempt when cancellation arrived")
        XCTAssertEqual(hitTest.callCount, 0)
        XCTAssertEqual(coordinate.callCount, 0)
        let applescriptEntry = result.decisionLog.first { $0.layer == "applescript" }
        XCTAssertEqual(applescriptEntry?.outcome, .cancelled,
                       "AppleScript layer entry must show .cancelled outcome")
    }

    func test_preCancelledContext_stopsBeforeFirstLayerAttempt() async {
        let ax = FakeInteractionLayer(name: "ax_semantic")
        let applescript = FakeInteractionLayer(name: "applescript")
        ax.stubbedOutcome = .succeeded(method: "ax_semantic", confidence: 0.95)

        let token = CancellationToken()
        token.cancel()
        let context = ToolCallContext(requestId: "req", cancellation: token)

        let router = InteractionRouter(
            layers: [ax, applescript],
            registry: registry
        )

        let result = await router.route(input: input(), context: context)

        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.errorCode, "cancelled")
        XCTAssertEqual(ax.callCount, 0, "no layer should run when context arrives pre-cancelled")
        XCTAssertEqual(applescript.callCount, 0)
    }
}

/// Thin observing wrapper. Runs `beforeAttempt` synchronously before delegating
/// to the wrapped layer. Lets tests inject cancellation at a precise point in
/// the loop (e.g. "between AX layer completing and AppleScript layer starting").
private final class ObservingLayer: InteractionLayer {
    let name: String
    let registryFlag: KeyPath<CapabilitiesResult, CapabilityFlag>?
    let registryFlagName: String?
    private let wrapped: FakeInteractionLayer
    private let beforeAttempt: () -> Void

    init(wrapped: FakeInteractionLayer, beforeAttempt: @escaping () -> Void) {
        self.wrapped = wrapped
        self.beforeAttempt = beforeAttempt
        self.name = wrapped.name
        self.registryFlag = wrapped.registryFlag
        self.registryFlagName = wrapped.registryFlagName
    }

    func attempt(
        _ intent: InteractionIntent,
        target: TargetSpec,
        context: ToolCallContext
    ) async -> LayerOutcome {
        beforeAttempt()
        return await wrapped.attempt(intent, target: target, context: context)
    }
}
