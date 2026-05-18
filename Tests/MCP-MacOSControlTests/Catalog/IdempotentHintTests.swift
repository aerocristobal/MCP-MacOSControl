import XCTest
import MCP
@testable import MacOSControlLib

/// STORY-011 Scenario 7 — verify that idempotency hints are set explicitly on
/// every tool. The matrix asserts representative tools in each direction; the
/// catalog-wide check that `idempotentHint != nil` lives in
/// `ToolCatalogAuditTests` (the matrix here covers known-good values).
final class IdempotentHintTests: XCTestCase {

    private var allTools: [Tool] { ToolRouter.allTools }

    // MARK: - Read-only tools should be idempotent (safe to retry)

    func test_readOnlyTools_haveIdempotentHintTrue() {
        let idempotentReadOnlyTools = [
            "accessibility_tree",
            "find_elements",
            "element_at_position",
            "take_screenshot",
            "take_screenshot_with_ocr",
            "get_screen_size",
            "list_displays",
            "list_windows",
            "list_capturable_displays",
            "list_capturable_windows",
            "list_capturable_applications",
            "classify_image",
            "detect_objects",
            "detect_rectangles",
            "detect_saliency",
            "detect_faces",
            "list_coreml_models",
            "get_model_info",
            "check_permissions",
            "iphone_status",
            "iphone_screenshot",
            "iphone_screenshot_with_ocr",
        ]
        for name in idempotentReadOnlyTools {
            guard let tool = allTools.first(where: { $0.name == name }) else {
                XCTFail("Idempotent read-only tool '\(name)' not registered")
                continue
            }
            XCTAssertEqual(
                tool.annotations.idempotentHint, true,
                "\(name) is read-only and should declare idempotentHint = true"
            )
        }
    }

    // MARK: - State-modifying or sampling tools should be non-idempotent

    func test_nonIdempotentTools_haveIdempotentHintFalse() {
        let nonIdempotentTools = [
            // Sampling / non-deterministic output
            "generate_text_llm",
            "analyze_screen_with_llm",
            "intelligent_screen_summary",
            "analyze_screen_now",
            "iphone_analyze_screen_now",
            "iphone_analyze_with_llm",
            // Side-effecting destructive controls
            "click_screen",
            "click_element",
            "perform_ax_action",
            "run_applescript",
            "click_menu_item",
            // Polling / event-driven tools — outcome depends on time-varying screen state
            "wait_for_text",
            "wait_milliseconds",
            "iphone_wait_for_text",
            "wait_for_ui_event",
            // Frame advances on each call
            "get_capture_frame",
        ]
        for name in nonIdempotentTools {
            guard let tool = allTools.first(where: { $0.name == name }) else {
                XCTFail("Non-idempotent tool '\(name)' not registered")
                continue
            }
            XCTAssertEqual(
                tool.annotations.idempotentHint, false,
                "\(name) should declare idempotentHint = false"
            )
        }
    }
}
