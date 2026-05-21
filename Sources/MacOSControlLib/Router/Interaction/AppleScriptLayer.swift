import Foundation

// STORY-010 — Layer 2: AppleScript. Adapter over STORY-006's
// `AppleScriptExecuting`.
//
// Skip vs fail (Three Amigos Q3):
//   • skip — no `application` to address a `tell` block to, or a `type` intent
//            (generic text entry has no portable pure-AppleScript form without
//            System Events, which the security layer forbids).
//   • fail — the script ran and `osascript` returned an error / timed out.
//
// v1 scope: a generic UI router cannot synthesize arbitrary clicks in pure
// AppleScript (that needs System Events, blocked by STORY-006's filter). The
// layer therefore issues the one portable, app-domain action it safely can —
// `activate` — which is the correct AppleScript step for the canonical
// "open/raise the app so the next layer can act" fallback. App-specific domain
// scripting remains the agent's job via the dedicated `run_applescript` tool.
public final class AppleScriptLayer: InteractionLayer {

    public let name = "applescript"
    public let registryFlag: KeyPath<CapabilitiesResult, CapabilityFlag>? = \.applescriptSupported
    public let registryFlagName: String? = "applescript_supported"

    private let executor: AppleScriptExecuting
    private let timeout: TimeInterval

    public init(executor: AppleScriptExecuting, timeout: TimeInterval = 30) {
        self.executor = executor
        self.timeout = timeout
    }

    public func attempt(_ intent: InteractionIntent, target: TargetSpec) async -> LayerOutcome {
        guard let app = target.application, !app.isEmpty else {
            return .skipped(reason: "no application to address an AppleScript tell block")
        }
        guard intent == .click else {
            return .skipped(reason: "type intent has no portable pure-AppleScript form")
        }

        let escaped = app.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"\(escaped)\" to activate"

        do {
            let outcome = try await executor.run(script, timeout: timeout)
            switch outcome {
            case .success:
                return .succeeded(method: name, confidence: 0.85)
            case .failure(let error):
                return .failed(errorCode: "applescript_error", message: appleScriptMessage(error))
            }
        } catch {
            return .failed(errorCode: "applescript_error", message: error.localizedDescription)
        }
    }

    private func appleScriptMessage(_ error: AppleScriptError) -> String {
        switch error {
        case .scriptError(let code, let message):
            return "osascript error \(code): \(message)"
        case .timeout(let after):
            return "timed out after \(after)s"
        case .ioError(let detail):
            return detail
        case .cancelled:
            return "tool call was cancelled"
        }
    }
}
