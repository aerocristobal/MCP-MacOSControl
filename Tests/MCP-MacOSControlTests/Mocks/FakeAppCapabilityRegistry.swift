import Foundation
@testable import MacOSControlLib

// STORY-019 — Read-only registry double for CapabilityRegistryResource tests.
// STORY-020 — Extended with a per-bundle stub method so the catalog generator
// tests can build a fixture registry without constructing CapabilityEntry by hand.
final class FakeAppCapabilityRegistry: CapabilityRegistryReading {

    private var entries: [CapabilityEntry] = []
    var schemaVersion: Int = 1
    var lastModified: Date = Date(timeIntervalSince1970: 1_700_000_000)

    func stubEntries(_ entries: [CapabilityEntry]) {
        self.entries = entries
    }

    /// Convenience used by STORY-020 catalog generator tests. Appends (or
    /// replaces) one entry by bundle id; defaults `source` to `.defaults` so
    /// `DiscrepancyDetector.expectedMethod(...)` honors it (`.unknown` source
    /// suppresses the hard expectation by design).
    func stubCapability(
        forBundle bundleId: String,
        axSupported: Bool,
        applescriptSupported: Bool,
        hitTestSupported: Bool = true,
        source: CapabilitySource = .defaults
    ) {
        let entry = CapabilityEntry(
            bundleId: bundleId,
            axSupported: CapabilityFlag(bool: axSupported),
            applescriptSupported: CapabilityFlag(bool: applescriptSupported),
            hitTestSupported: CapabilityFlag(bool: hitTestSupported),
            source: source
        )
        entries.removeAll { $0.bundleId == bundleId }
        entries.append(entry)
    }

    var allEntries: [CapabilityEntry] { entries }
}
