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
    ]

    public static var allTools: [Tool] {
        modules.flatMap { $0.tools }
    }

    public static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        for module in modules {
            if let result = try await module.handle(params) {
                return result
            }
        }
        return .init(content: [.text("Unknown tool: \(params.name)")], isError: false)
    }
}
