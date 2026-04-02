import XCTest
import MCP
@testable import MacOSControlLib

final class ToolSchemaTests: XCTestCase {

    private func findTool(_ name: String) -> Tool {
        ToolRouter.allTools.first { $0.name == name }!
    }

    // MARK: - Screen Analysis Tools

    func testAnalyzeScreenNowRequiredParams() {
        let tool = findTool("analyze_screen_now")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testStartScreenMonitoringRequiredParams() {
        let tool = findTool("start_screen_monitoring")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testGetMonitoringResultsRequiredParams() {
        let tool = findTool("get_monitoring_results")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testStopScreenMonitoringRequiredParams() {
        let tool = findTool("stop_screen_monitoring")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    // MARK: - Permission Tools

    func testCheckPermissionsRequiredParams() {
        let tool = findTool("check_permissions")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    // MARK: - Utility Tools

    func testWaitMillisecondsRequiredParams() {
        let tool = findTool("wait_milliseconds")
        XCTAssertEqual(requiredParams(for: tool), ["milliseconds"])
    }

    // MARK: - CoreML Tools

    func testListCoremlModelsRequiredParams() {
        let tool = findTool("list_coreml_models")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testLoadCoremlModelRequiredParams() {
        let tool = findTool("load_coreml_model")
        XCTAssertEqual(Set(requiredParams(for: tool)), Set(["name", "path"]))
    }

    func testUnloadCoremlModelRequiredParams() {
        let tool = findTool("unload_coreml_model")
        XCTAssertEqual(requiredParams(for: tool), ["name"])
    }

    func testGetModelInfoRequiredParams() {
        let tool = findTool("get_model_info")
        XCTAssertEqual(requiredParams(for: tool), ["name"])
    }

    // MARK: - LLM Tools

    func testGenerateTextLlmRequiredParams() {
        let tool = findTool("generate_text_llm")
        XCTAssertEqual(Set(requiredParams(for: tool)), Set(["model_name", "prompt"]))
    }

    func testAnalyzeScreenWithLlmRequiredParams() {
        let tool = findTool("analyze_screen_with_llm")
        XCTAssertEqual(Set(requiredParams(for: tool)), Set(["model_name", "instruction"]))
    }

    func testIntelligentScreenSummaryRequiredParams() {
        let tool = findTool("intelligent_screen_summary")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testExtractKeyInfoRequiredParams() {
        let tool = findTool("extract_key_info")
        XCTAssertEqual(requiredParams(for: tool), ["ocr_results"])
    }

    // MARK: - Mouse Tools

    func testClickScreenRequiredParams() {
        let tool = findTool("click_screen")
        XCTAssertEqual(Set(requiredParams(for: tool)), Set(["x", "y"]))
    }

    func testGetScreenSizeRequiredParams() {
        let tool = findTool("get_screen_size")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testMoveMouseRequiredParams() {
        let tool = findTool("move_mouse")
        XCTAssertEqual(Set(requiredParams(for: tool)), Set(["x", "y"]))
    }

    func testMouseDownRequiredParams() {
        let tool = findTool("mouse_down")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testMouseUpRequiredParams() {
        let tool = findTool("mouse_up")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testDragMouseRequiredParams() {
        let tool = findTool("drag_mouse")
        XCTAssertEqual(Set(requiredParams(for: tool)), Set(["from_x", "from_y", "to_x", "to_y"]))
    }

    // MARK: - Keyboard Tools

    func testTypeTextRequiredParams() {
        let tool = findTool("type_text")
        XCTAssertEqual(requiredParams(for: tool), ["text"])
    }

    func testKeyDownRequiredParams() {
        let tool = findTool("key_down")
        XCTAssertEqual(requiredParams(for: tool), ["key"])
    }

    func testKeyUpRequiredParams() {
        let tool = findTool("key_up")
        XCTAssertEqual(requiredParams(for: tool), ["key"])
    }

    func testPressKeysRequiredParams() {
        let tool = findTool("press_keys")
        XCTAssertEqual(requiredParams(for: tool), ["keys"])
    }

    // MARK: - Screenshot Tools

    func testTakeScreenshotRequiredParams() {
        let tool = findTool("take_screenshot")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testTakeScreenshotWithOcrRequiredParams() {
        let tool = findTool("take_screenshot_with_ocr")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    // MARK: - Window Tools

    func testListWindowsRequiredParams() {
        let tool = findTool("list_windows")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testActivateWindowRequiredParams() {
        let tool = findTool("activate_window")
        XCTAssertEqual(requiredParams(for: tool), ["title_pattern"])
    }

    // MARK: - Capture Tools

    func testStartContinuousCaptureRequiredParams() {
        let tool = findTool("start_continuous_capture")
        XCTAssertEqual(requiredParams(for: tool), ["capture_type"])
    }

    func testStopContinuousCaptureRequiredParams() {
        let tool = findTool("stop_continuous_capture")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testGetCaptureFrameRequiredParams() {
        let tool = findTool("get_capture_frame")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testListCapturableDisplaysRequiredParams() {
        let tool = findTool("list_capturable_displays")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testListCapturableWindowsRequiredParams() {
        let tool = findTool("list_capturable_windows")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testListCapturableApplicationsRequiredParams() {
        let tool = findTool("list_capturable_applications")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    // MARK: - Vision Tools

    func testClassifyImageRequiredParams() {
        let tool = findTool("classify_image")
        XCTAssertEqual(requiredParams(for: tool), ["image_data"])
    }

    func testDetectObjectsRequiredParams() {
        let tool = findTool("detect_objects")
        XCTAssertEqual(requiredParams(for: tool), ["image_data"])
    }

    func testDetectRectanglesRequiredParams() {
        let tool = findTool("detect_rectangles")
        XCTAssertEqual(requiredParams(for: tool), ["image_data"])
    }

    func testDetectSaliencyRequiredParams() {
        let tool = findTool("detect_saliency")
        XCTAssertEqual(requiredParams(for: tool), ["image_data"])
    }

    func testDetectFacesRequiredParams() {
        let tool = findTool("detect_faces")
        XCTAssertEqual(requiredParams(for: tool), ["image_data"])
    }

    // MARK: - iPhone Mirroring Tools

    func testIPhoneStatusRequiredParams() {
        let tool = findTool("iphone_status")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testIPhoneLaunchRequiredParams() {
        let tool = findTool("iphone_launch")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testIPhoneCalibrateRequiredParams() {
        let tool = findTool("iphone_calibrate")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testIPhoneTapRequiredParams() {
        let tool = findTool("iphone_tap")
        XCTAssertEqual(Set(requiredParams(for: tool)), Set(["x", "y"]))
    }

    func testIPhoneDoubleTapRequiredParams() {
        let tool = findTool("iphone_double_tap")
        XCTAssertEqual(Set(requiredParams(for: tool)), Set(["x", "y"]))
    }

    func testIPhoneLongPressRequiredParams() {
        let tool = findTool("iphone_long_press")
        XCTAssertEqual(Set(requiredParams(for: tool)), Set(["x", "y"]))
    }

    func testIPhoneSwipeRequiredParams() {
        let tool = findTool("iphone_swipe")
        XCTAssertEqual(Set(requiredParams(for: tool)), Set(["start_x", "start_y", "end_x", "end_y"]))
    }

    func testIPhoneScrollRequiredParams() {
        let tool = findTool("iphone_scroll")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testIPhoneTypeTextRequiredParams() {
        let tool = findTool("iphone_type_text")
        XCTAssertEqual(requiredParams(for: tool), ["text"])
    }

    func testIPhoneClearTextRequiredParams() {
        let tool = findTool("iphone_clear_text")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testIPhonePressKeyRequiredParams() {
        let tool = findTool("iphone_press_key")
        XCTAssertEqual(requiredParams(for: tool), ["key"])
    }

    func testIPhoneHomeRequiredParams() {
        let tool = findTool("iphone_home")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testIPhoneAppSwitcherRequiredParams() {
        let tool = findTool("iphone_app_switcher")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testIPhoneSpotlightRequiredParams() {
        let tool = findTool("iphone_spotlight")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testIPhoneScreenshotRequiredParams() {
        let tool = findTool("iphone_screenshot")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testIPhoneScreenshotWithOcrRequiredParams() {
        let tool = findTool("iphone_screenshot_with_ocr")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testIPhoneAnalyzeScreenNowRequiredParams() {
        let tool = findTool("iphone_analyze_screen_now")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    func testIPhoneAnalyzeWithLlmRequiredParams() {
        let tool = findTool("iphone_analyze_with_llm")
        XCTAssertEqual(Set(requiredParams(for: tool)), Set(["model_name", "instruction"]))
    }

    // MARK: - New Phase 3 Tools

    func testScrollRequiredParams() {
        let tool = findTool("scroll")
        XCTAssertEqual(Set(requiredParams(for: tool)), Set(["direction"]))
    }

    func testDoubleClickRequiredParams() {
        let tool = findTool("double_click")
        XCTAssertEqual(Set(requiredParams(for: tool)), Set(["x", "y"]))
    }

    func testWaitForTextRequiredParams() {
        let tool = findTool("wait_for_text")
        XCTAssertEqual(requiredParams(for: tool), ["text"])
    }

    func testAccessibilityTreeRequiredParams() {
        let tool = findTool("accessibility_tree")
        XCTAssertEqual(requiredParams(for: tool), [])
    }

    // MARK: - Schema Structure

    func testAllToolsHaveObjectSchema() {
        for tool in ToolRouter.allTools {
            guard case .object(let dict) = tool.inputSchema else {
                XCTFail("Tool \(tool.name) inputSchema is not an object")
                continue
            }
            XCTAssertEqual(dict["type"], .string("object"), "Tool \(tool.name) schema type should be 'object'")
        }
    }
}
