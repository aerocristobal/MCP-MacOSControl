import Foundation
@testable import MacOSControlLib

// STORY-019 — Read-only registry double for CapabilityRegistryResource tests.
final class FakeAppCapabilityRegistry: CapabilityRegistryReading {

    private var entries: [CapabilityEntry] = []
    var schemaVersion: Int = 1
    var lastModified: Date = Date(timeIntervalSince1970: 1_700_000_000)

    func stubEntries(_ entries: [CapabilityEntry]) {
        self.entries = entries
    }

    var allEntries: [CapabilityEntry] { entries }
}
