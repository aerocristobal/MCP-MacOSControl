import Foundation
@testable import MacOSControlLib

// STORY-010 — configurable InteractionLayer double. Lets InteractionRouter be
// tested without real accessibility / AppleScript C-calls.
final class FakeInteractionLayer: InteractionLayer {

    let name: String
    var stubbedOutcome: LayerOutcome = .skipped(reason: "no stub configured")

    private(set) var callCount = 0
    private(set) var lastIntent: InteractionIntent?
    private(set) var lastValue: String?
    private(set) var lastTarget: TargetSpec?

    init(name: String) {
        self.name = name
    }

    var registryFlag: KeyPath<CapabilitiesResult, CapabilityFlag>? {
        switch name {
        case "ax_semantic": return \.axSupported
        case "applescript": return \.applescriptSupported
        case "ax_hit_test": return \.hitTestSupported
        default: return nil
        }
    }

    var registryFlagName: String? {
        switch name {
        case "ax_semantic": return "ax_supported"
        case "applescript": return "applescript_supported"
        case "ax_hit_test": return "hit_test_supported"
        default: return nil
        }
    }

    func attempt(_ intent: InteractionIntent, target: TargetSpec) async -> LayerOutcome {
        callCount += 1
        lastIntent = intent
        lastValue = target.value
        lastTarget = target
        return stubbedOutcome
    }
}
