import Foundation
@testable import MacOSControlLib

final class AppleScriptExecutorSpy: AppleScriptExecuting {
    enum Stub {
        case success(stdout: String, durationMs: Int, truncated: Bool = false)
        case failure(AppleScriptError)
    }

    var stubbedResult: Stub = .success(stdout: "", durationMs: 0)
    var runCallCount = 0
    var lastScript: String?
    var lastTimeout: TimeInterval?

    func run(_ script: String, timeout: TimeInterval) throws -> AppleScriptExecutionResult {
        runCallCount += 1
        lastScript = script
        lastTimeout = timeout
        switch stubbedResult {
        case .success(let stdout, let durationMs, let truncated):
            return .success(stdout: stdout, durationMs: durationMs, truncated: truncated)
        case .failure(let error):
            return .failure(error)
        }
    }
}
