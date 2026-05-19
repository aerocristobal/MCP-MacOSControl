import Foundation
@testable import MacOSControlLib

// STORY-019 — Captures structured override errors instead of writing stderr.
final class FakeStructuredLogger: CapabilityRegistryLogging {

    private(set) var loggedErrorCodes: [String] = []
    private(set) var loggedFilePaths: [String] = []
    private(set) var loggedLines: [Int?] = []
    private(set) var loggedMessages: [String] = []

    func logOverrideError(filePath: String, line: Int?, message: String) {
        loggedErrorCodes.append(AppCapabilityRegistry.overrideErrorCode)
        loggedFilePaths.append(filePath)
        loggedLines.append(line)
        loggedMessages.append(message)
    }
}
