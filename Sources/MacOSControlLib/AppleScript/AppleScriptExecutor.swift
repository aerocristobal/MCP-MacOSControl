import Foundation

public enum AppleScriptError: Error, Equatable {
    case scriptError(code: Int, message: String)
    case timeout(after: TimeInterval)
    case ioError(String)
    /// STORY-027 — caller cancelled the tool call mid-execution. The osascript
    /// subprocess was terminated (SIGTERM, then SIGKILL if it didn't exit within
    /// 1000ms). No stdout/stderr is captured.
    case cancelled
}

public enum AppleScriptExecutionResult: Equatable {
    case success(stdout: String, durationMs: Int, truncated: Bool)
    case failure(AppleScriptError)
}

public protocol AppleScriptExecuting {
    /// Runs the script with the given timeout. STORY-027 — the `context`
    /// carries a `CancellationToken`; if it is cancelled mid-execution the
    /// osascript subprocess is sent SIGTERM and, if it does not exit within
    /// 1000ms, SIGKILL. The result in that case is `.failure(.cancelled)`.
    func run(
        _ script: String,
        timeout: TimeInterval,
        context: ToolCallContext
    ) async throws -> AppleScriptExecutionResult
}

public extension AppleScriptExecuting {
    /// Convenience for call sites that aren't yet wired for cancellation. The
    /// non-cancellable context never fires, so this is exactly the previous
    /// behaviour.
    func run(
        _ script: String,
        timeout: TimeInterval
    ) async throws -> AppleScriptExecutionResult {
        try await run(script, timeout: timeout, context: .nonCancellable())
    }
}

public final class AppleScriptExecutor: AppleScriptExecuting {

    public static let outputLimitBytes = 1_024 * 1_024  // 1 MB cap per Open Question 4

    /// SIGTERM → SIGKILL escalation budget. The first 1.0 seconds after
    /// cancellation gives osascript time to handle SIGTERM (cleanup `tell`
    /// blocks). After that we force-kill.
    public static let sigkillEscalationDelaySeconds: TimeInterval = 1.0

    private let osascriptPath: String

    public init(osascriptPath: String = "/usr/bin/osascript") {
        self.osascriptPath = osascriptPath
    }

    public func run(
        _ script: String,
        timeout: TimeInterval,
        context: ToolCallContext
    ) async throws -> AppleScriptExecutionResult {
        // Fast-path: caller is already cancelled before we even spawn anything.
        if context.cancellation.isCancelled {
            return .failure(.cancelled)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: osascriptPath)
        process.arguments = ["-e", script]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let state = ExecutorState(
            process: process,
            stdoutPipe: stdoutPipe,
            stderrPipe: stderrPipe,
            timeout: timeout,
            sigkillEscalationDelay: Self.sigkillEscalationDelaySeconds
        )

        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<AppleScriptExecutionResult, Never>) in
                state.continuation = continuation
                process.terminationHandler = { proc in
                    state.handleTermination(process: proc)
                }
                context.cancellation.onCancel { [weak state] in
                    state?.requestCancel()
                }
                do {
                    try process.run()
                    state.recordStart()
                    state.scheduleTimeoutTermination()
                    // Race: if the token was cancelled between the isCancelled
                    // check above and the onCancel registration, fire now.
                    if context.cancellation.isCancelled {
                        state.requestCancel()
                    }
                } catch {
                    state.finishWithIOError("failed to launch osascript: \(error.localizedDescription)")
                }
            }
        } onCancel: {
            // The SDK's task-cancellation reaches us here. Forwarding to the
            // token keeps the single onCancel path canonical; the token's own
            // idempotency guards against double-fire.
            context.cancellation.cancel()
        }
    }
}

/// Holds the per-call state shared between the termination handler, the
/// timeout work-item, and the cancellation callback. All access is serialised
/// behind an `NSLock` so the three paths can race safely; whichever wins
/// resumes the continuation, the others observe `finished = true` and bail.
private final class ExecutorState: @unchecked Sendable {

    private let lock = NSLock()
    private let process: Process
    private let stdoutPipe: Pipe
    private let stderrPipe: Pipe
    private let timeout: TimeInterval
    private let sigkillEscalationDelay: TimeInterval

    private var finished = false
    private var cancelled = false
    private var timedOut = false
    private var startedAt: Date?

    var continuation: CheckedContinuation<AppleScriptExecutionResult, Never>?

    init(
        process: Process,
        stdoutPipe: Pipe,
        stderrPipe: Pipe,
        timeout: TimeInterval,
        sigkillEscalationDelay: TimeInterval
    ) {
        self.process = process
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        self.timeout = timeout
        self.sigkillEscalationDelay = sigkillEscalationDelay
    }

    func recordStart() {
        lock.lock()
        startedAt = Date()
        lock.unlock()
    }

    /// SIGTERM the subprocess; if it doesn't exit within
    /// `sigkillEscalationDelay`, send SIGKILL. Idempotent.
    func requestCancel() {
        lock.lock()
        guard !finished && !cancelled else {
            lock.unlock()
            return
        }
        cancelled = true
        let pid = process.processIdentifier
        let isRunning = process.isRunning
        lock.unlock()
        if isRunning && pid > 0 {
            kill(pid, SIGTERM)
            DispatchQueue.global().asyncAfter(deadline: .now() + sigkillEscalationDelay) { [weak self] in
                guard let self else { return }
                self.lock.lock()
                let stillRunning = self.process.isRunning && !self.finished
                let pidNow = self.process.processIdentifier
                self.lock.unlock()
                if stillRunning && pidNow > 0 {
                    kill(pidNow, SIGKILL)
                }
            }
        }
    }

    /// Same shape as `requestCancel` but marks the timeout path so the result
    /// is reported as `.timeout` rather than `.cancelled`. Mirrors the existing
    /// behaviour.
    func scheduleTimeoutTermination() {
        let scheduled = DispatchTime.now() + timeout
        DispatchQueue.global().asyncAfter(deadline: scheduled) { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let runningAndUnfinished = self.process.isRunning && !self.finished && !self.cancelled
            let pid = self.process.processIdentifier
            if runningAndUnfinished {
                self.timedOut = true
            }
            self.lock.unlock()
            if runningAndUnfinished && pid > 0 {
                kill(pid, SIGTERM)
            }
        }
    }

    func handleTermination(process proc: Process) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let wasCancelled = cancelled
        let wasTimedOut = timedOut
        let cont = continuation
        continuation = nil
        let startedAt = self.startedAt
        lock.unlock()

        guard let cont else { return }

        if wasCancelled {
            cont.resume(returning: .failure(.cancelled))
            return
        }

        if wasTimedOut {
            cont.resume(returning: .failure(.timeout(after: timeout)))
            return
        }

        let elapsed = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        let durationMs = Int((elapsed * 1000).rounded())

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let (stdout, truncated) = AppleScriptExecutorIO.truncate(
            stdoutData,
            limit: AppleScriptExecutor.outputLimitBytes
        )
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        if proc.terminationStatus == 0 {
            cont.resume(returning: .success(stdout: stdout, durationMs: durationMs, truncated: truncated))
            return
        }

        let (code, message) = AppleScriptExecutorIO.parseError(
            stderr: stderr,
            fallbackCode: Int(proc.terminationStatus)
        )
        cont.resume(returning: .failure(.scriptError(code: code, message: message)))
    }

    func finishWithIOError(_ detail: String) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(returning: .failure(.ioError(detail)))
    }
}

/// Pure helpers, no shared state — kept file-private so the implementation
/// stays cohesive.
private enum AppleScriptExecutorIO {

    static func truncate(_ data: Data, limit: Int) -> (String, Bool) {
        if data.count <= limit {
            let s = String(data: data, encoding: .utf8) ?? ""
            return (s, false)
        }
        let head = data.prefix(limit)
        let s = String(data: head, encoding: .utf8) ?? ""
        return (s, true)
    }

    /// osascript stderr format example:
    ///   `0:0: execution error: Can't get name of front window. (-1728)`
    /// Extract the trailing parenthesised number (signed) and the human message.
    static func parseError(stderr: String, fallbackCode: Int) -> (Int, String) {
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"\((-?\d+)\)\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(
               in: trimmed,
               options: [],
               range: NSRange(trimmed.startIndex..., in: trimmed)
           ),
           match.numberOfRanges >= 2,
           let codeRange = Range(match.range(at: 1), in: trimmed),
           let code = Int(trimmed[codeRange])
        {
            let messageRange = Range(match.range, in: trimmed)!
            let message = trimmed[..<messageRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (code, message.isEmpty ? trimmed : message)
        }
        return (fallbackCode, trimmed.isEmpty ? "osascript failed with no diagnostic output" : trimmed)
    }
}
