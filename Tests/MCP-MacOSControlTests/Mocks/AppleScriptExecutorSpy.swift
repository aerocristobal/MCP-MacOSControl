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
    var lastContext: ToolCallContext?

    /// Optional artificial latency. STORY-027 — tests of cancellation propagation
    /// stub a delay so the cancellation can race with the simulated work.
    var simulatedDelayNanoseconds: UInt64 = 0

    func run(
        _ script: String,
        timeout: TimeInterval,
        context: ToolCallContext
    ) async throws -> AppleScriptExecutionResult {
        runCallCount += 1
        lastScript = script
        lastTimeout = timeout
        lastContext = context

        if simulatedDelayNanoseconds > 0 {
            // Cooperative: check the token periodically so we can react to cancel.
            let step: UInt64 = 10_000_000 // 10ms
            var remaining = simulatedDelayNanoseconds
            while remaining > 0 {
                if context.cancellation.isCancelled {
                    return .failure(.cancelled)
                }
                let chunk = min(step, remaining)
                try? await Task.sleep(nanoseconds: chunk)
                remaining -= chunk
            }
        }

        if context.cancellation.isCancelled {
            return .failure(.cancelled)
        }

        switch stubbedResult {
        case .success(let stdout, let durationMs, let truncated):
            return .success(stdout: stdout, durationMs: durationMs, truncated: truncated)
        case .failure(let error):
            return .failure(error)
        }
    }
}
