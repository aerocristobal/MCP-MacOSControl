import Foundation

// STORY-010 — Layer 1: AX semantic. Adapter over STORY-002/003 services
// (`AXElementResolving` + `AXElementInteracting`).
//
// Skip vs fail (Three Amigos Q3):
//   • skip  — system-wide AX permission missing (configuration, not runtime).
//   • fail  — an attempt was made and a structured AX error came back
//             (element_not_found, ax_resolution_failed, ax_action_failed).
//
// v1 target resolution: the intent-first `target_description` is treated as the
// element's AX title (the overwhelmingly common locator). Richer NL→locator
// resolution is deliberately out of scope; on a miss the layer returns `.failed`
// and the router falls through to AppleScript / hit-test.
//
// v1 type path: there is no set-AXValue seam on `AXElementInteracting` (it
// dispatches AX *actions*, not attribute writes). The layer dispatches the
// symbolic action `AXSetAttribute:AXValue`; a real interactor rejects it as
// unsupported and the router falls through to AppleScript / coordinate. This
// keeps the change surgical (no bridge/interactor surface growth) while
// preserving the canonical ordering.
public final class AXSemanticLayer: InteractionLayer {

    public let name = "ax_semantic"
    public let registryFlag: KeyPath<CapabilitiesResult, CapabilityFlag>? = \.axSupported
    public let registryFlagName: String? = "ax_supported"

    static let typeActionToken = "AXSetAttribute:AXValue"

    private let resolver: AXElementResolving
    private let interactor: AXElementInteracting

    public init(resolver: AXElementResolving, interactor: AXElementInteracting) {
        self.resolver = resolver
        self.interactor = interactor
    }

    public func attempt(
        _ intent: InteractionIntent,
        target: TargetSpec,
        context: ToolCallContext
    ) async -> LayerOutcome {
        guard let description = target.description, !description.isEmpty else {
            return .skipped(reason: "no target_description for AX resolution")
        }
        let scope = axScope(for: target.application)

        let resolved: AXElementReference
        do {
            resolved = try resolver.findElement(role: nil, title: description, scope: scope)
        } catch let permission as MCPError where isPermission(permission) {
            return .skipped(reason: "AX permission not granted: \(permission.message)")
        } catch let notFound as AXNotFoundError {
            return .failed(errorCode: "element_not_found", message: notFound.searchCriteria)
        } catch let resolution as AXResolutionError {
            return .failed(errorCode: resolution.errorCode, message: resolution.detail)
        } catch {
            return .failed(errorCode: "element_not_found", message: error.localizedDescription)
        }

        do {
            switch intent {
            case .click:
                try interactor.performPress(resolved)
            case .type:
                try interactor.perform(Self.typeActionToken, on: resolved)
            }
        } catch let permission as MCPError where isPermission(permission) {
            return .skipped(reason: "AX permission not granted: \(permission.message)")
        } catch let action as AXActionError {
            return .failed(errorCode: action.errorCode, message: action.detail)
        } catch {
            return .failed(errorCode: "ax_action_failed", message: error.localizedDescription)
        }

        return .succeeded(method: name, confidence: 0.95)
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

/// Mirrors `ClickElementTool.scope(for:)`: a dotted string is a bundle id, a
/// bare name is an app name, empty/absent is unscoped (search all processes).
func axScope(for application: String?) -> AXResolverScope? {
    guard let application = application, !application.isEmpty else { return nil }
    return application.contains(".") ? .bundleId(application) : .name(application)
}
