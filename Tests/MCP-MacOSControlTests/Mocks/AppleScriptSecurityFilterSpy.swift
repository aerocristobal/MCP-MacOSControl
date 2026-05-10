import Foundation
@testable import MacOSControlLib

final class AppleScriptSecurityFilterSpy: AppleScriptSecurityFiltering {
    enum Rejection {
        case doShellScript
        case doJavaScript
        case loadScript
        case systemEventsTell
        case custom(rule: String, detail: String)
    }

    var shouldReject: Rejection?
    var validateCallCount = 0
    var lastScript: String?

    func validate(_ script: String) throws {
        validateCallCount += 1
        lastScript = script
        guard let rejection = shouldReject else { return }
        switch rejection {
        case .doShellScript:
            throw AppleScriptSecurityError(matchedRule: "do_shell_script",
                                           detail: "do shell script rejected")
        case .doJavaScript:
            throw AppleScriptSecurityError(matchedRule: "do_javascript",
                                           detail: "do JavaScript rejected")
        case .loadScript:
            throw AppleScriptSecurityError(matchedRule: "load_script",
                                           detail: "load script rejected")
        case .systemEventsTell:
            throw AppleScriptSecurityError(matchedRule: "system_events_tell",
                                           detail: "tell System Events rejected")
        case .custom(let rule, let detail):
            throw AppleScriptSecurityError(matchedRule: rule, detail: detail)
        }
    }
}
