import Foundation
import ApplicationServices

public final class AXElementInteractor: AXElementInteracting {
    private let bridge: AXApplicationBridge

    public init(bridge: AXApplicationBridge) {
        self.bridge = bridge
    }

    public func performPress(_ ref: AXElementReference) throws {
        let action = kAXPressAction as String
        guard bridge.isEnabled(ref) else {
            throw AXActionError(
                code: .elementDisabled,
                action: action,
                detail: "element \(describe(ref)) is not enabled"
            )
        }
        do {
            try bridge.performAction(action, on: ref)
        } catch let resolution as AXResolutionError {
            throw AXActionError(
                code: .actionFailed,
                action: action,
                detail: resolution.detail,
                underlyingCode: resolution.underlyingCode
            )
        } catch {
            throw AXActionError(
                code: .actionFailed,
                action: action,
                detail: error.localizedDescription
            )
        }
    }

    private func describe(_ ref: AXElementReference) -> String {
        var parts: [String] = []
        if let r = ref.role { parts.append("role=\(r)") }
        if let t = ref.title { parts.append("title=\(t)") }
        if let id = ref.identifier { parts.append("identifier=\(id)") }
        if let l = ref.label { parts.append("label=\(l)") }
        return parts.isEmpty ? "(no attrs)" : parts.joined(separator: ", ")
    }
}
