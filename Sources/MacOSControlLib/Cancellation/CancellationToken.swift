import Foundation

/// Cooperative cancellation primitive for long-running MCP tool calls.
///
/// STORY-027 — the MCP server bridges the Swift-SDK's task cancellation (triggered
/// by `notifications/cancelled`) into instances of this token so that non-Task
/// waiters — AX continuations, NSWorkspace observers, polling loops, osascript
/// subprocesses — can observe cancellation and tear down their resources.
///
/// Reference semantics are deliberate: callbacks must fire synchronously when
/// `cancel()` is invoked so that AX continuations can resume on the actor that
/// owns them without re-entering. The internal `NSLock` keeps `@Sendable` honest.
public final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var _isCancelled: Bool = false
    private var callbacks: [() -> Void] = []

    public let reason: String?

    public init(reason: String? = nil) {
        self.reason = reason
    }

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCancelled
    }

    /// Register a teardown closure. If the token has already been cancelled the
    /// handler is invoked synchronously before this call returns — callers must
    /// be safe to be re-entered on whatever thread invoked `cancel()`.
    public func onCancel(_ handler: @escaping @Sendable () -> Void) {
        lock.lock()
        if _isCancelled {
            lock.unlock()
            handler()
            return
        }
        callbacks.append(handler)
        lock.unlock()
    }

    /// Idempotent. Fires every registered callback exactly once.
    public func cancel() {
        lock.lock()
        guard !_isCancelled else {
            lock.unlock()
            return
        }
        _isCancelled = true
        let toFire = callbacks
        callbacks.removeAll()
        lock.unlock()
        for callback in toFire {
            callback()
        }
    }

    /// Throws `CancellationError` if the token has been cancelled. Used by
    /// polling loops and any code that wants to opt into structured-concurrency
    /// cancellation semantics.
    public func checkCancellation() throws {
        if isCancelled {
            throw CancellationError()
        }
    }
}
