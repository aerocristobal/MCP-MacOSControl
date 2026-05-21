import Foundation

/// Per-call context threaded through `ToolModule.handle(_:context:)`.
///
/// STORY-027 — gives every tool access to (a) the server-generated correlator
/// `requestId` for log enrichment and (b) the `CancellationToken` it should
/// observe for cooperative cancellation. Quick tools may ignore both fields;
/// long-running tools wire `cancellation.onCancel { ... }` to release their
/// resources when the caller abandons the request.
public struct ToolCallContext: Sendable {
    public let requestId: String
    public let cancellation: CancellationToken

    public init(requestId: String, cancellation: CancellationToken) {
        self.requestId = requestId
        self.cancellation = cancellation
    }

    /// Convenience for tests and callers that don't participate in cancellation.
    /// The returned token is never cancelled.
    public static func nonCancellable(requestId: String = "test") -> ToolCallContext {
        ToolCallContext(requestId: requestId, cancellation: CancellationToken())
    }
}
