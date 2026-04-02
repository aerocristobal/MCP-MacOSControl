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
    ]

    public static var allTools: [Tool] {
        modules.flatMap { $0.tools }
    }

    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        let start = DispatchTime.now()
        MCPLogger.trace("Tool call: \(params.name)")

        for module in modules {
            if let result = try await module.handle(params) {
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
                if result.isError == true {
                    MCPLogger.warn("\(params.name) failed in \(Int(elapsed))ms")
                } else {
                    MCPLogger.debug("\(params.name) completed in \(Int(elapsed))ms")
                }
                return result
            }
        }

        MCPLogger.warn("Unknown tool: \(params.name)")
        return .init(content: [.text("Unknown tool: \(params.name)")], isError: false)
    }
}
