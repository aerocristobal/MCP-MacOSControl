import Foundation
@testable import MacOSControlLib

// STORY-010 — query-seam double for InteractionRouter tests. Unstubbed bundle
// ids resolve to `.unknown` (the optimistic-attempt path, Three Amigos Q1).
final class StubCapabilityQuerying: CapabilityQuerying {

    private var byBundle: [String: CapabilitiesResult] = [:]

    func stubCapability(
        forBundle bundleId: String,
        axSupported: Bool,
        applescriptSupported: Bool,
        hitTestSupported: Bool = true
    ) {
        byBundle[bundleId] = CapabilitiesResult(
            axSupported: CapabilityFlag(bool: axSupported),
            applescriptSupported: CapabilityFlag(bool: applescriptSupported),
            hitTestSupported: CapabilityFlag(bool: hitTestSupported),
            source: .userOverride
        )
    }

    func capabilities(for bundleId: String) -> CapabilitiesResult {
        byBundle[bundleId] ?? .unknown
    }
}
