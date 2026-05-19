import Foundation
@testable import MacOSControlLib

// STORY-019 — Test double for the bundled defaults loader.
// Stubs the JSON content the registry would otherwise read from
// Bundle.module's Router/Defaults/default-app-capabilities.json.
final class FakeBundleResourceLoader: DefaultCapabilitiesLoading {

    private var stubbed: String?

    /// The `name` argument is recorded for fidelity with the story scaffold
    /// call sites; the registry only ever asks for the one bundled file.
    private(set) var requestedNames: [String] = []

    func stubResource(_ name: String, content: String) {
        requestedNames.append(name)
        stubbed = content
    }

    var stubbedModifiedAt: Date?

    func load() throws -> LoadedDefaults {
        guard let stubbed else {
            throw NSError(domain: "FakeBundleResourceLoader", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "no stubbed default-app-capabilities.json"])
        }
        return LoadedDefaults(data: Data(stubbed.utf8), modifiedAt: stubbedModifiedAt)
    }
}
