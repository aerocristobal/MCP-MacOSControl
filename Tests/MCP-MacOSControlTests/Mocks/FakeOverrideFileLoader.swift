import Foundation
@testable import MacOSControlLib

// STORY-019 — Test double for the user override file loader.
final class FakeOverrideFileLoader: OverrideCapabilitiesLoading {

    private var stubbedContent: String?
    private var stubbedPath: String = "/fake/app-overrides.json"
    private var readError: Error?
    var stubbedModifiedAt: Date?

    func stubFile(_ name: String, content: String) {
        stubbedPath = name
        stubbedContent = content
    }

    /// Simulate the file existing but being unreadable (permissions, etc.).
    func stubReadFailure(_ error: Error) {
        readError = error
    }

    func load() throws -> OverrideSource? {
        if let readError { throw readError }
        guard let stubbedContent else { return nil }
        return OverrideSource(data: Data(stubbedContent.utf8), path: stubbedPath, modifiedAt: stubbedModifiedAt)
    }
}
