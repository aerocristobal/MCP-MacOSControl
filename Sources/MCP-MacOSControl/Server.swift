import Foundation
import MCP
import MacOSControlLib

@main
enum MacOSControlServer {
    static func main() async throws {
        let server = Server(
            name: "mcp-macos-control",
            version: "1.0.0",
            instructions: """
                MCP-MacOSControl: 65 tools for macOS and iPhone automation.

                COORDINATE SYSTEMS:
                - macOS tools (click_screen, move_mouse, etc.): absolute pixel coordinates
                - iPhone tools (iphone_tap, iphone_swipe, etc.): normalized 0.0-1.0 where (0,0)=top-left, (1,1)=bottom-right

                KEY PATTERNS:

                1. macOS interaction: Use take_screenshot_with_ocr or accessibility_tree to find elements, then click_screen/type_text to interact.

                2. iPhone interaction (observe-reason-act loop):
                   a. iphone_screenshot_with_ocr to see current screen and get text coordinates
                   b. Identify target element from OCR results
                   c. iphone_tap at the element's normalized coordinates (use OCR coords directly)
                   d. iphone_wait_for_text to confirm the action took effect before next step

                3. Opening an iPhone app: Use iphone_open_app (handles Spotlight sequence automatically).

                4. Waiting for UI transitions: Use wait_for_text (macOS) or iphone_wait_for_text (iPhone) instead of fixed delays. These poll OCR until specific text appears.

                5. Accessibility tree: Use accessibility_tree for macOS app UI structure (role, label, position). Does NOT work for iPhone Mirroring content.

                TOOL CATEGORIES:
                - Mouse (9): click_screen, double_click, move_mouse, mouse_down/up, drag_mouse, scroll, get_screen_size, list_displays
                - Keyboard (4): type_text, press_keys, key_down, key_up
                - Screen (2): take_screenshot, take_screenshot_with_ocr
                - Windows (2): list_windows, activate_window
                - System (3): check_permissions, wait_milliseconds, wait_for_text
                - Accessibility (1): accessibility_tree
                - iPhone Mirroring (21): iphone_launch, iphone_tap, iphone_swipe, iphone_type_text, iphone_screenshot_with_ocr, iphone_open_app, iphone_wait_for_text, and more
                - Vision (5), CoreML (8), Realtime (4), Continuous Capture (6)
                """,
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
