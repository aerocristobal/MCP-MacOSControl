// STORY-012 — End-to-End Integration Validation Suite
// COMPONENT: Capture stderr around a region of code.
//
// `MCPLogger.log` writes via `fputs(..., stderr)`, so the only way to assert on
// a server log entry from a test is to dup2 stderr to a pipe for the relevant
// window, then restore it and read the captured bytes. Used by the gated
// PermissionRevocationTests path to verify the gherkin clause "the server logs
// the revocation event with a structured log entry".

import Foundation
import Darwin

enum StderrCapture {

    /// Runs `body` with stderr (fd 2) redirected to an internal pipe. Returns
    /// the captured text. Stderr is restored regardless of whether `body`
    /// throws. Safe to use from a single test at a time.
    static func capture(_ body: () async throws -> Void) async throws -> String {
        let savedStderr = dup(STDERR_FILENO)
        precondition(savedStderr >= 0, "dup(STDERR_FILENO) failed")

        var pipeFds: [Int32] = [0, 0]
        guard pipe(&pipeFds) == 0 else {
            close(savedStderr)
            preconditionFailure("pipe() failed")
        }
        let readEnd = pipeFds[0]
        let writeEnd = pipeFds[1]

        dup2(writeEnd, STDERR_FILENO)
        close(writeEnd)

        defer {
            // Restore stderr first so the test framework's own writes go back
            // to the real stderr; close the read end last so we drain it.
            dup2(savedStderr, STDERR_FILENO)
            close(savedStderr)
            close(readEnd)
        }

        do {
            try await body()
        } catch {
            // Even on failure, drain what was captured before re-throwing —
            // makes error context far more debuggable.
            let captured = drain(readEnd)
            print("[StderrCapture] body threw; captured so far:\n\(captured)")
            throw error
        }

        return drain(readEnd)
    }

    /// Non-blocking drain: set the read end to O_NONBLOCK and read until EAGAIN.
    private static func drain(_ fd: Int32) -> String {
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        var collected = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = read(fd, &buffer, buffer.count)
            if n > 0 {
                collected.append(buffer, count: n)
            } else {
                break
            }
        }
        return String(data: collected, encoding: .utf8) ?? ""
    }
}
