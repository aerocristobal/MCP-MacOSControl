import Foundation
import CoreGraphics

// STORY-010 — Layer 4: raw coordinate fallback. Adapter over the existing
// MouseControl / KeyboardControl statics (via `CoordinateActuating`). The last
// resort — never registry-skipped (`registryFlag == nil`); the caller is told
// it is the least reliable method (the SmartInteractTool surfaces a warning).
//
// Skip vs fail (Three Amigos Q3):
//   • skip — `click` with no coordinates (nothing to aim at).
//   • fail — the CGEvent post threw.
//
// type behavior: if coordinates are supplied, click them first to focus the
// field, then dispatch the keystrokes; otherwise type into whatever is already
// focused.
public final class CoordinateLayer: InteractionLayer {

    public let name = "coordinate_fallback"
    public let registryFlag: KeyPath<CapabilitiesResult, CapabilityFlag>? = nil
    public let registryFlagName: String? = nil

    private let actuator: CoordinateActuating

    public init(actuator: CoordinateActuating) {
        self.actuator = actuator
    }

    public func attempt(
        _ intent: InteractionIntent,
        target: TargetSpec,
        context: ToolCallContext
    ) async -> LayerOutcome {
        switch intent {
        case .click:
            guard let coords = target.coordinates else {
                return .skipped(reason: "no coordinates for coordinate fallback")
            }
            do {
                try actuator.click(x: Int(coords.x), y: Int(coords.y))
            } catch {
                return .failed(errorCode: "input_failed", message: error.localizedDescription)
            }
            return .succeeded(method: name, confidence: 0.5)

        case .type:
            guard let value = target.value else {
                return .skipped(reason: "no value supplied for type intent")
            }
            do {
                if let coords = target.coordinates {
                    try actuator.click(x: Int(coords.x), y: Int(coords.y))
                }
                try await actuator.typeText(value)
            } catch {
                return .failed(errorCode: "input_failed", message: error.localizedDescription)
            }
            return .succeeded(method: name, confidence: 0.5)
        }
    }
}
