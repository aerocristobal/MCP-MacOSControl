import Foundation

// STORY-010 — Agent Interaction Hierarchy Router
//
// Routes one `SmartInteractInput` through the canonical four-layer order
// (AX semantic → AppleScript → hit-test → coordinate), consulting the
// STORY-019 capability registry first to skip layers known to fail for the
// target app, and recording every attempt/skip/fail in an ordered decision log.

/// Seam so `SmartInteractTool` can be unit-tested against a stub router.
public protocol InteractionRouting {
    func route(input: SmartInteractInput) async -> RouterResult
}

public final class InteractionRouter: InteractionRouting {

    private let layers: [InteractionLayer]
    private let registry: CapabilityQuerying
    private let now: () -> Date

    public init(
        layers: [InteractionLayer],
        registry: CapabilityQuerying,
        now: @escaping () -> Date = Date.init
    ) {
        self.layers = layers
        self.registry = registry
        self.now = now
    }

    public func route(input: SmartInteractInput) async -> RouterResult {
        var log: [DecisionLogEntry] = []
        // Failed (not skipped) attempts decay later layers' confidence — a
        // success after two failed layers is less trustworthy (Q2).
        var priorFailures = 0

        let capabilities = registry.capabilities(for: input.application ?? "")
        let target = TargetSpec(
            description: input.targetDescription,
            application: input.application,
            coordinates: input.coordinates,
            value: input.value
        )

        for layer in layers {
            // 1. Per-call skip override (Q6).
            if input.skipLayers.contains(layer.name) {
                log.append(DecisionLogEntry(
                    layer: layer.name,
                    attempted: false,
                    outcome: .skipped,
                    reason: "skip_layers override"
                ))
                continue
            }

            // 2. Registry-driven skip (Q1/Q3): a hard `.no` means the layer is
            //    known-broken for this app — skip without an attempt so we
            //    waste neither wall-clock nor log noise. `.unknown` is
            //    optimistic (attempt anyway).
            if let flagPath = layer.registryFlag,
               capabilities[keyPath: flagPath] == .no {
                let flagName = layer.registryFlagName ?? "capability"
                log.append(DecisionLogEntry(
                    layer: layer.name,
                    attempted: false,
                    outcome: .skipped,
                    reason: "registry: \(flagName)=false"
                ))
                continue
            }

            // 3. Attempt. The layer self-reports `.skipped` for an
            //    inapplicable intent / missing prerequisite (e.g. hit-test
            //    with no coordinates, or type intent).
            let start = now()
            let outcome = await layer.attempt(input.intent, target: target)
            let elapsedMs = Int(now().timeIntervalSince(start) * 1000)

            switch outcome {
            case .succeeded(let method, let baseline):
                let confidence = baseline * pow(0.9, Double(priorFailures))
                var metadata: [String: String] = [:]
                if let coords = input.coordinates, layer.name == "ax_hit_test" {
                    metadata["coordinates"] = "(\(coords.x), \(coords.y))"
                }
                log.append(DecisionLogEntry(
                    layer: layer.name,
                    attempted: true,
                    outcome: .succeeded,
                    reason: "",
                    elapsedMs: elapsedMs,
                    metadata: metadata
                ))
                return RouterResult(
                    interactionMethod: method,
                    confidence: confidence,
                    decisionLog: log,
                    result: successPayload(input: input, method: method)
                )

            case .skipped(let reason):
                log.append(DecisionLogEntry(
                    layer: layer.name,
                    attempted: false,
                    outcome: .skipped,
                    reason: reason,
                    elapsedMs: elapsedMs
                ))

            case .failed(let code, let message):
                priorFailures += 1
                var metadata: [String: String] = [:]
                if let coords = input.coordinates, layer.name == "ax_hit_test" {
                    metadata["coordinates"] = "(\(coords.x), \(coords.y))"
                }
                log.append(DecisionLogEntry(
                    layer: layer.name,
                    attempted: true,
                    outcome: .failed,
                    reason: "\(code): \(message)",
                    elapsedMs: elapsedMs,
                    metadata: metadata
                ))
            }
        }

        // Every layer skipped or failed — structured all_layers_failed (Q3).
        return RouterResult(
            interactionMethod: "",
            confidence: 0,
            decisionLog: log,
            isError: true,
            errorCode: "all_layers_failed",
            details: [
                "decision_log": log.map(\.asDictionary),
                "retry_suggestions": [
                    "Retry with a different intent or a more specific target_description.",
                    "If the app may be frozen, wait_for_app_event for it to become responsive, then retry.",
                    "As a last resort, fall back to explicit coordinate tools (click_screen / type_text) after take_screenshot_with_ocr."
                ]
            ]
        )
    }

    /// v1 layer-specific payload is a compact echo of what was dispatched. The
    /// agent verifies the *effect* itself via wait_for_* (Three Amigos Q7).
    private func successPayload(input: SmartInteractInput, method: String) -> [String: String] {
        var payload: [String: String] = [
            "intent": input.intent.rawValue,
            "method": method
        ]
        if let t = input.targetDescription { payload["target_description"] = t }
        if let app = input.application { payload["application"] = app }
        if let v = input.value { payload["value"] = v }
        return payload
    }
}
