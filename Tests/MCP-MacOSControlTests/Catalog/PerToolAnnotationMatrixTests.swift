import XCTest
import MCP
@testable import MacOSControlLib

/// STORY-011 Scenario 8 — per-tool annotation matrix. The expectations array
/// below is the single source of truth and must mirror the matrix in the
/// approved plan. STORY-008 adds `wait_for_ui_event`; STORY-009 adds
/// `wait_for_element_state` (read-only, idempotent in intent).
final class PerToolAnnotationMatrixTests: XCTestCase {

    private struct ExpectedAnnotation {
        let toolName: String
        let readOnly: Bool
        let destructive: Bool
        let idempotent: Bool
    }

    /// Source of truth for the 77 currently-registered tools. Adding a tool to
    /// `ToolRouter` without a row here will make `test_matrixCoversEveryRegisteredTool`
    /// fail — that is the intended TDD signal for new contributors.
    private static let expectations: [ExpectedAnnotation] = [
        // Accessibility (5)
        .init(toolName: "accessibility_tree",          readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "click_element",               readOnly: false, destructive: true,  idempotent: false),
        .init(toolName: "perform_ax_action",           readOnly: false, destructive: true,  idempotent: false),
        .init(toolName: "find_elements",               readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "element_at_position",         readOnly: true,  destructive: false, idempotent: true),

        // AppleScript (2)
        .init(toolName: "run_applescript",             readOnly: false, destructive: true,  idempotent: false),
        .init(toolName: "click_menu_item",             readOnly: false, destructive: true,  idempotent: false),

        // Mouse (9)
        .init(toolName: "click_screen",                readOnly: false, destructive: true,  idempotent: false),
        .init(toolName: "double_click",                readOnly: false, destructive: true,  idempotent: false),
        .init(toolName: "drag_mouse",                  readOnly: false, destructive: true,  idempotent: false),
        .init(toolName: "mouse_down",                  readOnly: false, destructive: true,  idempotent: false),
        .init(toolName: "mouse_up",                    readOnly: false, destructive: true,  idempotent: false),
        .init(toolName: "move_mouse",                  readOnly: false, destructive: false, idempotent: true),
        .init(toolName: "scroll",                      readOnly: false, destructive: false, idempotent: false),
        .init(toolName: "get_screen_size",             readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "list_displays",               readOnly: true,  destructive: false, idempotent: true),

        // Keyboard (4)
        .init(toolName: "type_text",                   readOnly: false, destructive: false, idempotent: false),
        .init(toolName: "key_down",                    readOnly: false, destructive: false, idempotent: false),
        .init(toolName: "key_up",                      readOnly: false, destructive: false, idempotent: false),
        .init(toolName: "press_keys",                  readOnly: false, destructive: false, idempotent: false),

        // ScreenCapture (2)
        .init(toolName: "take_screenshot",             readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "take_screenshot_with_ocr",    readOnly: true,  destructive: false, idempotent: true),

        // Window (2)
        .init(toolName: "list_windows",                readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "activate_window",             readOnly: false, destructive: false, idempotent: true),

        // ContinuousCapture (6)
        .init(toolName: "start_continuous_capture",    readOnly: false, destructive: false, idempotent: false),
        .init(toolName: "stop_continuous_capture",     readOnly: false, destructive: false, idempotent: true),
        .init(toolName: "get_capture_frame",           readOnly: true,  destructive: false, idempotent: false),
        .init(toolName: "list_capturable_displays",    readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "list_capturable_windows",     readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "list_capturable_applications",readOnly: true,  destructive: false, idempotent: true),

        // Vision (5)
        .init(toolName: "classify_image",              readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "detect_objects",              readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "detect_rectangles",           readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "detect_saliency",             readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "detect_faces",                readOnly: true,  destructive: false, idempotent: true),

        // CoreML (8)
        .init(toolName: "list_coreml_models",          readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "load_coreml_model",           readOnly: false, destructive: false, idempotent: true),
        .init(toolName: "unload_coreml_model",         readOnly: false, destructive: false, idempotent: true),
        .init(toolName: "get_model_info",              readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "generate_text_llm",           readOnly: true,  destructive: false, idempotent: false),
        .init(toolName: "analyze_screen_with_llm",     readOnly: true,  destructive: false, idempotent: false),
        .init(toolName: "intelligent_screen_summary",  readOnly: true,  destructive: false, idempotent: false),
        .init(toolName: "extract_key_info",            readOnly: true,  destructive: false, idempotent: true),

        // Realtime (4)
        .init(toolName: "analyze_screen_now",          readOnly: true,  destructive: false, idempotent: false),
        .init(toolName: "start_screen_monitoring",     readOnly: false, destructive: false, idempotent: false),
        .init(toolName: "get_monitoring_results",      readOnly: true,  destructive: false, idempotent: false),
        .init(toolName: "stop_screen_monitoring",      readOnly: false, destructive: false, idempotent: true),

        // System (3)
        .init(toolName: "check_permissions",           readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "wait_milliseconds",           readOnly: true,  destructive: false, idempotent: false),
        .init(toolName: "wait_for_text",               readOnly: true,  destructive: false, idempotent: false),

        // Event-driven waiting (STORY-008)
        .init(toolName: "wait_for_ui_event",           readOnly: true,  destructive: false, idempotent: false),

        // Element-state polling (STORY-009)
        .init(toolName: "wait_for_element_state",      readOnly: true,  destructive: false, idempotent: true),

        // Application lifecycle events (STORY-018)
        .init(toolName: "wait_for_app_event",          readOnly: true,  destructive: false, idempotent: false),

        // IPhoneMirroring (21)
        .init(toolName: "iphone_status",               readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "iphone_launch",               readOnly: false, destructive: false, idempotent: true),
        .init(toolName: "iphone_calibrate",            readOnly: false, destructive: false, idempotent: true),
        .init(toolName: "iphone_tap",                  readOnly: false, destructive: true,  idempotent: false),
        .init(toolName: "iphone_double_tap",           readOnly: false, destructive: true,  idempotent: false),
        .init(toolName: "iphone_long_press",           readOnly: false, destructive: true,  idempotent: false),
        .init(toolName: "iphone_swipe",                readOnly: false, destructive: true,  idempotent: false),
        .init(toolName: "iphone_scroll",               readOnly: false, destructive: false, idempotent: false),
        .init(toolName: "iphone_type_text",            readOnly: false, destructive: false, idempotent: false),
        .init(toolName: "iphone_clear_text",           readOnly: false, destructive: true,  idempotent: false),
        .init(toolName: "iphone_press_key",            readOnly: false, destructive: false, idempotent: false),
        .init(toolName: "iphone_home",                 readOnly: false, destructive: false, idempotent: true),
        .init(toolName: "iphone_app_switcher",         readOnly: false, destructive: false, idempotent: true),
        .init(toolName: "iphone_spotlight",            readOnly: false, destructive: false, idempotent: true),
        .init(toolName: "iphone_screenshot",           readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "iphone_screenshot_with_ocr",  readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "iphone_analyze_screen_now",   readOnly: true,  destructive: false, idempotent: false),
        .init(toolName: "iphone_analyze_with_llm",     readOnly: true,  destructive: false, idempotent: false),
        .init(toolName: "iphone_open_app",             readOnly: false, destructive: false, idempotent: false),
        .init(toolName: "iphone_wait_for_text",        readOnly: true,  destructive: false, idempotent: false),
        .init(toolName: "iphone_reconnect",            readOnly: false, destructive: false, idempotent: true),

        // Router (1) — STORY-010. Conservative: may click any control or
        // overwrite text, and the routed outcome depends on live UI state.
        .init(toolName: "smart_interact",              readOnly: false, destructive: true,  idempotent: false),

        // Audit admin (2) — STORY-024. verify_audit_chain is a read-only
        // integrity probe; force_rotate_unacked is destructive (accepted log
        // loss) and gated by MCP_MACOS_CONTROL_AUDIT_ADMIN_ENABLED=true.
        .init(toolName: "verify_audit_chain",          readOnly: true,  destructive: false, idempotent: true),
        .init(toolName: "force_rotate_unacked",        readOnly: false, destructive: true,  idempotent: false),
    ]

    func test_eachTool_hasExpectedAnnotation() {
        let tools = ToolRouter.allTools
        for expected in Self.expectations {
            guard let tool = tools.first(where: { $0.name == expected.toolName }) else {
                XCTFail("Expected tool '\(expected.toolName)' is not registered in ToolRouter")
                continue
            }
            XCTAssertEqual(
                tool.annotations.readOnlyHint, expected.readOnly,
                "\(expected.toolName) readOnlyHint mismatch"
            )
            XCTAssertEqual(
                tool.annotations.destructiveHint, expected.destructive,
                "\(expected.toolName) destructiveHint mismatch"
            )
            XCTAssertEqual(
                tool.annotations.idempotentHint, expected.idempotent,
                "\(expected.toolName) idempotentHint mismatch"
            )
        }
    }

    func test_matrixCoversEveryRegisteredTool() {
        let expectedNames = Set(Self.expectations.map(\.toolName))
        let registeredNames = Set(ToolRouter.allTools.map(\.name))

        let missingFromMatrix = registeredNames.subtracting(expectedNames)
        XCTAssertTrue(
            missingFromMatrix.isEmpty,
            "Tools registered but not in the expectations matrix: \(missingFromMatrix.sorted())"
        )

        let staleInMatrix = expectedNames.subtracting(registeredNames)
        XCTAssertTrue(
            staleInMatrix.isEmpty,
            "Tools in the expectations matrix but no longer registered: \(staleInMatrix.sorted())"
        )
    }
}
