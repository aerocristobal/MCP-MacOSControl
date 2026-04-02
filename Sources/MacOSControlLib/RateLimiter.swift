import Foundation

public enum RateLimiter {
    private static var tokens: Double = 0
    private static var lastRefill: UInt64 = 0
    private static let lock = NSLock()

    /// Maximum input events per second. Configurable via MCP_MACOS_CONTROL_MAX_INPUT_RATE.
    public static var maxRate: Double {
        if let env = ProcessInfo.processInfo.environment["MCP_MACOS_CONTROL_MAX_INPUT_RATE"],
           let rate = Double(env), rate > 0 {
            return rate
        }
        return 10.0
    }

    /// Check if an input event is allowed. Throws MCPError.rateLimited if rate exceeded.
    public static func checkInputAllowed() throws {
        lock.lock()
        defer { lock.unlock() }

        let now = DispatchTime.now().uptimeNanoseconds
        let rate = maxRate

        // Initialize on first call
        if lastRefill == 0 {
            lastRefill = now
            tokens = rate
        }

        // Refill tokens based on elapsed time
        let elapsed = Double(now - lastRefill) / 1_000_000_000.0 // seconds
        tokens = min(rate, tokens + elapsed * rate)
        lastRefill = now

        // Check if we have a token
        if tokens >= 1.0 {
            tokens -= 1.0
        } else {
            throw MCPError.rateLimited("Rate limit exceeded. Maximum \(Int(rate)) input events per second. Configure via MCP_MACOS_CONTROL_MAX_INPUT_RATE.")
        }
    }

    /// Reset the rate limiter (for testing).
    public static func reset() {
        lock.lock()
        defer { lock.unlock() }
        tokens = 0
        lastRefill = 0
    }
}
