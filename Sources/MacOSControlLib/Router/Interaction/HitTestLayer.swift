import Foundation
import CoreGraphics

// STORY-010 — Layer 3: visual hit-test. Adapter over STORY-005
// (`AXApplicationBridge.copyElementAtPosition`) + STORY-003
// (`AXElementInteracting`). Recovers an AXUIElement from a screenshot/OCR
// coordinate, then presses it — the inverse of resolve-by-name.
//
// Skip vs fail (Three Amigos Q3):
//   • skip — `type` intent (hit-test resolves a press target, not a text
//            field), or no coordinates supplied.
//   • fail — permission/AX error, or nothing hit-testable at the point.
public final class HitTestLayer: InteractionLayer {

    public let name = "ax_hit_test"
    public let registryFlag: KeyPath<CapabilitiesResult, CapabilityFlag>? = \.hitTestSupported
    public let registryFlagName: String? = "hit_test_supported"

    private let bridge: AXApplicationBridge
    private let interactor: AXElementInteracting

    public init(bridge: AXApplicationBridge, interactor: AXElementInteracting) {
        self.bridge = bridge
        self.interactor = interactor
    }

    public func attempt(_ intent: InteractionIntent, target: TargetSpec) async -> LayerOutcome {
        guard intent == .click else {
            return .skipped(reason: "type intent does not use hit-test")
        }
        guard let coords = target.coordinates else {
            return .skipped(reason: "no coordinates supplied for hit-test")
        }

        let element: AXElementReference?
        do {
            element = try bridge.copyElementAtPosition(globalX: coords.x, globalY: coords.y)
        } catch let permission as MCPError where isPermission(permission) {
            return .skipped(reason: "AX permission not granted: \(permission.message)")
        } catch let resolution as AXResolutionError {
            return .failed(errorCode: resolution.errorCode, message: resolution.detail)
        } catch {
            return .failed(errorCode: "ax_resolution_failed", message: error.localizedDescription)
        }

        guard let resolved = element else {
            return .failed(
                errorCode: "no_hit_at_position",
                message: "no AX element at (\(coords.x), \(coords.y))")
        }

        do {
            try interactor.performPress(resolved)
        } catch let action as AXActionError {
            return .failed(errorCode: action.errorCode, message: action.detail)
        } catch {
            return .failed(errorCode: "ax_action_failed", message: error.localizedDescription)
        }

        return .succeeded(method: name, confidence: 0.75)
    }

    private func isPermission(_ error: MCPError) -> Bool {
        switch error {
        case .permissionDenied, .accessibilityPermissionRequired:
            return true
        default:
            return false
        }
    }
}
