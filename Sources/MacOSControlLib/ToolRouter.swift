import Foundation
import MCP

public enum ToolRouter {
    public static let modules: [ToolModule.Type] = [
        MouseModule.self,
        KeyboardModule.self,
        ScreenCaptureModule.self,
        WindowModule.self,
        ContinuousCaptureModule.self,
        VisionModule.self,
        CoreMLModule.self,
        RealtimeModule.self,
        SystemModule.self,
        IPhoneMirroringModule.self,
        AccessibilityModule.self,
        AppleScriptModule.self,
        AuditAdminModule.self,
        WaitForUIEventModule.self,
        WaitForElementStateModule.self,
        WaitForAppEventModule.self,
        SmartInteractModule.self,
    ]

    public static var allTools: [Tool] {
        modules.flatMap { $0.tools }
    }

    public static func handle(
        _ params: CallTool.Parameters,
        context: ToolCallContext
    ) async throws -> CallTool.Result {
        let start = DispatchTime.now()
        MCPLogger.trace("Tool call: \(params.name)")

        do {
            for module in modules {
                if let result = try await module.handle(params, context: context) {
                    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
                    if result.isError == true {
                        MCPLogger.warn("\(params.name) failed in \(Int(elapsed))ms")
                    } else {
                        MCPLogger.debug("\(params.name) completed in \(Int(elapsed))ms")
                    }
                    return result
                }
            }
        } catch is CancellationError {
            // STORY-027: when the SDK's task.cancel() races to the inside of a
            // tool implementation, the tool may throw `CancellationError`. The
            // SDK suppresses the response to the client (per
            // notifications/cancelled), so the value returned here is only
            // surfaced when the response is sent in the race window. We use the
            // registered `cancelled` error code per STORY-016.
            MCPLogger.debug("\(params.name) was cancelled mid-execution")
            return MCPErrorResponseBuilder.shared.build(
                code: "cancelled",
                message: "Tool execution was cancelled by the client."
            )
        } catch {
            // Any uncaught Swift error from a module is mapped to a structured
            // internal_error response per STORY-016 — the boundary never leaks
            // an unmapped exception to the JSON-RPC layer.
            MCPLogger.warn("\(params.name) raised uncaught error: \(error)")
            return MCPErrorResponseBuilder.shared.buildFromUnknown(error)
        }

        MCPLogger.warn("Unknown tool: \(params.name)")
        return MCPErrorResponseBuilder.shared.build(
            code: "unknown_tool",
            message: "Unknown tool: \(params.name)"
        )
    }

    /// Backwards-compatible convenience for callers that don't participate in
    /// cancellation. Forwards to the two-argument form with a non-cancellable
    /// context.
    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        try await handle(params, context: .nonCancellable())
    }
}
