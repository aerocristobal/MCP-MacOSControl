import Foundation

public enum AppleScriptError: Error, Equatable {
    case scriptError(code: Int, message: String)
    case timeout(after: TimeInterval)
    case ioError(String)
}

public enum AppleScriptExecutionResult: Equatable {
    case success(stdout: String, durationMs: Int, truncated: Bool)
    case failure(AppleScriptError)
}

public protocol AppleScriptExecuting {
    func run(_ script: String, timeout: TimeInterval) throws -> AppleScriptExecutionResult
}

public final class AppleScriptExecutor: AppleScriptExecuting {

    public static let outputLimitBytes = 1_024 * 1_024  // 1 MB cap per Open Question 4

    private let osascriptPath: String

    public init(osascriptPath: String = "/usr/bin/osascript") {
        self.osascriptPath = osascriptPath
    }

    public func run(_ script: String, timeout: TimeInterval) throws -> AppleScriptExecutionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: osascriptPath)
        process.arguments = ["-e", script]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let timeoutLock = NSLock()
        var didTimeout = false

        let start = Date()

        do {
            try process.run()
        } catch {
            return .failure(.ioError("failed to launch osascript: \(error.localizedDescription)"))
        }

        let timeoutWorkItem = DispatchWorkItem {
            guard process.isRunning else { return }
            timeoutLock.lock()
            didTimeout = true
            timeoutLock.unlock()
            process.terminate()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)

        process.waitUntilExit()
        timeoutWorkItem.cancel()

        let elapsed = Date().timeIntervalSince(start)
        let durationMs = Int((elapsed * 1000).rounded())

        timeoutLock.lock()
        let timedOut = didTimeout
        timeoutLock.unlock()

        if timedOut {
            return .failure(.timeout(after: timeout))
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let (stdout, truncated) = truncate(stdoutData)
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        if process.terminationStatus == 0 {
            return .success(stdout: stdout, durationMs: durationMs, truncated: truncated)
        }

        let (code, message) = parseAppleScriptError(
            stderr: stderr,
            fallbackCode: Int(process.terminationStatus)
        )
        return .failure(.scriptError(code: code, message: message))
    }

    private func truncate(_ data: Data) -> (String, Bool) {
        if data.count <= Self.outputLimitBytes {
            let s = String(data: data, encoding: .utf8) ?? ""
            return (s, false)
        }
        let head = data.prefix(Self.outputLimitBytes)
        let s = String(data: head, encoding: .utf8) ?? ""
        return (s, true)
    }

    /// osascript stderr format example:
    ///   `0:0: execution error: Can't get name of front window. (-1728)`
    /// Extract the trailing parenthesised number (signed) and the human message.
    private func parseAppleScriptError(stderr: String, fallbackCode: Int) -> (Int, String) {
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
            // Strip the trailing `(<code>)` to leave the human message.
            let messageRange = Range(match.range, in: trimmed)!
            let message = trimmed[..<messageRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (code, message.isEmpty ? trimmed : message)
        }
        return (fallbackCode, trimmed.isEmpty ? "osascript failed with no diagnostic output" : trimmed)
    }
}
