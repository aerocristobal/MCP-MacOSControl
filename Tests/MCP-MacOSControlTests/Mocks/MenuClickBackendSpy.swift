import Foundation
@testable import MacOSControlLib

final class MenuClickBackendSpy: MenuClickBackend {

    var stubbedClickResult: ClickResult = .success
    var stubbedClickError: Error?
    var stubbedAlternatives: [String] = []
    var stubbedAlternativesError: Error?

    private(set) var clickCallCount = 0
    private(set) var lastClickPath: [String]?
    private(set) var lastClickApplication: String?
    private(set) var lastDoNotActivate: Bool?

    private(set) var alternativesCallCount = 0
    private(set) var lastAlternativesPath: [String]?
    private(set) var lastAlternativesApplication: String?

    func click(path: [String], application: String, doNotActivate: Bool) async throws -> ClickResult {
        clickCallCount += 1
        lastClickPath = path
        lastClickApplication = application
        lastDoNotActivate = doNotActivate
        if let err = stubbedClickError { throw err }
        return stubbedClickResult
    }

    func alternatives(forFailingPath path: [String], application: String) async throws -> [String] {
        alternativesCallCount += 1
        lastAlternativesPath = path
        lastAlternativesApplication = application
        if let err = stubbedAlternativesError { throw err }
        return stubbedAlternatives
    }
}
