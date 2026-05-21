import Foundation

/// Server-side registry of in-flight tool calls keyed by request id.
///
/// STORY-027 — the MCP handler registers a `CancellationToken` here at the
/// start of each call, removes it via `finish` on normal completion, and
/// `cancelAll` is invoked on SIGTERM to drain in-flight work.
///
/// The Swift-SDK already routes `notifications/cancelled` into a `Task.cancel()`
/// on the handler task; this registry exists so server shutdown can reach the
/// same set of tokens uniformly.
public actor InFlightRegistry {
    private var tokens: [String: CancellationToken] = [:]

    public init() {}

    public func register(requestId: String, token: CancellationToken) {
        tokens[requestId] = token
    }

    /// Cancels the token for the given request id, if any. Returns `true` if a
    /// token was found and cancelled; `false` for unknown ids (the SDK already
    /// treats unknown ids as a no-op, this just mirrors the contract).
    @discardableResult
    public func cancel(requestId: String) -> Bool {
        guard let token = tokens.removeValue(forKey: requestId) else {
            return false
        }
        token.cancel()
        return true
    }

    /// Removes the entry for a request that completed normally. Idempotent.
    public func finish(requestId: String) {
        tokens.removeValue(forKey: requestId)
    }

    /// Cancels every in-flight token. Used by SIGTERM shutdown.
    public func cancelAll() {
        let snapshot = tokens
        tokens.removeAll()
        for token in snapshot.values {
            token.cancel()
        }
    }

    public func count() -> Int {
        tokens.count
    }
}
