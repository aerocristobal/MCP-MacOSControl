import Foundation
@testable import MacOSControlLib

final class MenuPathResolverSpy: MenuPathResolving {

    var stubbedScript: String = "tell application \"System Events\" to return"
    var stubbedAlternativesScript: String = "tell application \"System Events\" to return"

    private(set) var scriptCallCount = 0
    private(set) var alternativesScriptCallCount = 0
    private(set) var lastPath: [String]?
    private(set) var lastApplication: String?
    private(set) var lastDoNotActivate: Bool?
    private(set) var lastAlternativesPath: [String]?
    private(set) var lastAlternativesApplication: String?

    func script(for path: [String], application: String, doNotActivate: Bool) -> String {
        scriptCallCount += 1
        lastPath = path
        lastApplication = application
        lastDoNotActivate = doNotActivate
        return stubbedScript
    }

    func alternativesScript(for path: [String], application: String) -> String {
        alternativesScriptCallCount += 1
        lastAlternativesPath = path
        lastAlternativesApplication = application
        return stubbedAlternativesScript
    }
}
