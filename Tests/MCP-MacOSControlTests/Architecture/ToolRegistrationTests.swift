import XCTest
import MCP
@testable import MacOSControlLib

final class ToolRegistrationTests: XCTestCase {
    func testMouseModuleHas8Tools() {
        XCTAssertEqual(MouseModule.tools.count, 8)
    }

    func testKeyboardModuleHas4Tools() {
        XCTAssertEqual(KeyboardModule.tools.count, 4)
    }

    func testScreenCaptureModuleHas2Tools() {
        XCTAssertEqual(ScreenCaptureModule.tools.count, 2)
    }

    func testWindowModuleHas2Tools() {
        XCTAssertEqual(WindowModule.tools.count, 2)
    }

    func testContinuousCaptureModuleHas6Tools() {
        XCTAssertEqual(ContinuousCaptureModule.tools.count, 6)
    }

    func testVisionModuleHas5Tools() {
        XCTAssertEqual(VisionModule.tools.count, 5)
    }

    func testCoreMLModuleHas8Tools() {
        XCTAssertEqual(CoreMLModule.tools.count, 8)
    }

    func testRealtimeModuleHas4Tools() {
        XCTAssertEqual(RealtimeModule.tools.count, 4)
    }

    func testSystemModuleHas3Tools() {
        XCTAssertEqual(SystemModule.tools.count, 3)
    }

    func testAccessibilityModuleHas1Tool() {
        XCTAssertEqual(AccessibilityModule.tools.count, 1)
    }

    func testIPhoneMirroringModuleHas18Tools() {
        XCTAssertEqual(IPhoneMirroringModule.tools.count, 18)
    }

    func testMouseModuleToolNames() {
        let names = Set(MouseModule.tools.map(\.name))
        XCTAssertEqual(names, ["click_screen", "get_screen_size", "move_mouse", "mouse_down", "mouse_up", "drag_mouse", "double_click", "scroll"])
    }

    func testAllModulesToolNamesMatchExpected() {
        let expected: Set<String> = [
            "click_screen", "get_screen_size", "move_mouse", "mouse_down", "mouse_up", "drag_mouse", "scroll", "double_click",
            "type_text", "key_down", "key_up", "press_keys",
            "take_screenshot", "take_screenshot_with_ocr",
            "list_windows", "activate_window",
            "start_continuous_capture", "stop_continuous_capture", "get_capture_frame",
            "list_capturable_displays", "list_capturable_windows", "list_capturable_applications",
            "classify_image", "detect_objects", "detect_rectangles", "detect_saliency", "detect_faces",
            "list_coreml_models", "load_coreml_model", "unload_coreml_model", "get_model_info",
            "generate_text_llm", "analyze_screen_with_llm", "intelligent_screen_summary", "extract_key_info",
            "analyze_screen_now", "start_screen_monitoring", "get_monitoring_results", "stop_screen_monitoring",
            "check_permissions", "wait_milliseconds", "wait_for_text",
            "accessibility_tree",
            "iphone_status", "iphone_launch", "iphone_calibrate",
            "iphone_tap", "iphone_double_tap", "iphone_long_press",
            "iphone_swipe", "iphone_scroll", "iphone_type_text",
            "iphone_clear_text", "iphone_press_key", "iphone_home",
            "iphone_app_switcher", "iphone_spotlight", "iphone_screenshot",
            "iphone_screenshot_with_ocr", "iphone_analyze_screen_now",
            "iphone_analyze_with_llm"
        ]
        let actual = Set(ToolRouter.allTools.map(\.name))
        XCTAssertEqual(actual, expected)
    }
}
