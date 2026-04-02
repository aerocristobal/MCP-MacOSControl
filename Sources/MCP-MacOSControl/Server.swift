import Foundation
import MCP
import MacOSControlLib

@main
enum MacOSControlServer {
    static func main() async throws {
        let server = Server(
            name: "mcp-macos-control",
            version: "1.0.0",
            capabilities: .init(
                tools: .init(listChanged: true)
            )
        )

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: ToolRouter.allTools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            try await ToolRouter.handle(params)
        }

        let transport = StdioTransport()
        do {
            try await server.start(transport: transport)
            await server.waitUntilCompleted()
        } catch {
            fputs("Error starting server: \(error)\n", stderr)
            exit(1)
        }
    }
}
