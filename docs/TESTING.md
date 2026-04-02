# MCP-MacOSControl -- Manual Integration Test Checklist

Covers all 65 tools across 11 modules. Run after any significant change.

## Prerequisites

- [ ] `swift build` succeeds
- [ ] `swift test` -- all 178 tests pass
- [ ] Server running in Claude Desktop or MCP client
- [ ] Accessibility permission granted
- [ ] Screen Recording permission granted

## Mouse Tools (MouseModule -- 9 tools)

- [ ] `click_screen` -- left-click at specific coordinates
- [ ] `click_screen` with button="right" -- right-click opens context menu
- [ ] `double_click` -- double-click at coordinates (opens file in Finder)
- [ ] `move_mouse` -- move cursor to coordinates
- [ ] `mouse_down` -- hold left button
- [ ] `mouse_up` -- release left button
- [ ] `drag_mouse` -- drag between two points
- [ ] `scroll` with direction="down" -- scrolls document down
- [ ] `scroll` with direction="right" -- horizontal scroll
- [ ] `get_screen_size` -- returns screen dimensions
- [ ] `list_displays` -- returns all connected displays with IDs and resolutions

## Keyboard Tools (KeyboardModule -- 4 tools)

- [ ] `type_text` -- type text into focused field
- [ ] `press_keys` with `[["cmd", "c"]]` -- key combination
- [ ] `key_down` -- hold a key
- [ ] `key_up` -- release a key

## Screenshot and OCR (ScreenCaptureModule -- 2 tools)

- [ ] `take_screenshot` -- full screen capture returns PNG
- [ ] `take_screenshot` with title_pattern -- captures specific window
- [ ] `take_screenshot_with_ocr` -- screenshot + text extraction with bounding boxes

## Window Management (WindowModule -- 2 tools)

- [ ] `list_windows` -- returns JSON array of windows
- [ ] `activate_window` -- brings matching window to foreground

## Continuous Capture (ContinuousCaptureModule -- 6 tools)

- [ ] `start_continuous_capture` with capture_type="display"
- [ ] `get_capture_frame` -- returns latest frame as PNG
- [ ] `stop_continuous_capture` -- stops session
- [ ] `list_capturable_displays` -- lists available displays
- [ ] `list_capturable_windows` -- lists capturable windows
- [ ] `list_capturable_applications` -- lists running apps

## Vision Analysis (VisionModule -- 5 tools)

- [ ] `classify_image` -- returns classification labels with confidence
- [ ] `detect_objects` -- returns bounding boxes
- [ ] `detect_rectangles` -- detects UI elements
- [ ] `detect_saliency` -- returns attention regions
- [ ] `detect_faces` -- returns face bounding boxes

## CoreML Intelligence (CoreMLModule -- 8 tools)

- [ ] `list_coreml_models` -- lists models (may be empty if none installed)
- [ ] `load_coreml_model` -- loads a model by path
- [ ] `unload_coreml_model` -- unloads a model
- [ ] `get_model_info` -- returns model metadata
- [ ] `generate_text_llm` -- generates text from prompt
- [ ] `analyze_screen_with_llm` -- vision + LLM analysis
- [ ] `intelligent_screen_summary` -- NLP-based summary
- [ ] `extract_key_info` -- extracts entities from OCR

## Real-Time Analysis (RealtimeModule -- 4 tools)

- [ ] `analyze_screen_now` -- one-shot screen analysis
- [ ] `start_screen_monitoring` -- starts continuous analysis
- [ ] `get_monitoring_results` -- returns latest results
- [ ] `stop_screen_monitoring` -- stops monitoring

## System (SystemModule -- 3 tools)

- [ ] `check_permissions` -- reports Accessibility and Screen Recording status
- [ ] `wait_milliseconds` with 500 -- pauses for 500ms
- [ ] `wait_for_text` with text="some visible text" -- finds text via OCR polling

## Accessibility (AccessibilityModule -- 1 tool)

- [ ] `accessibility_tree` -- returns AXUIElement tree for frontmost app
- [ ] `accessibility_tree` with app_name="Calculator" -- returns Calculator's UI tree
- [ ] `accessibility_tree` with max_depth=1 -- limits tree depth

## iPhone Mirroring (IPhoneMirroringModule -- 21 tools)

Requires macOS 15 with iPhone Mirroring configured and iPhone connected.

### Status and Control
- [ ] `iphone_status` -- reports running state and connection status
- [ ] `iphone_launch` -- opens/activates iPhone Mirroring
- [ ] `iphone_calibrate` -- forces content rect re-detection

### Gestures
- [ ] `iphone_tap` with x=0.5, y=0.5 -- taps center of iPhone screen
- [ ] `iphone_double_tap` with x=0.5, y=0.5 -- double-taps
- [ ] `iphone_long_press` with x=0.5, y=0.5 -- long-presses
- [ ] `iphone_swipe` from (0.5, 0.8) to (0.5, 0.2) -- scrolls down
- [ ] `iphone_scroll` with delta_y=3 -- scroll wheel events

### Text Input
- [ ] `iphone_type_text` with focused text field -- pastes text
- [ ] `iphone_clear_text` -- clears focused field
- [ ] `iphone_press_key` with key="return" -- sends Return

### Navigation
- [ ] `iphone_home` -- returns to home screen
- [ ] `iphone_app_switcher` -- opens App Switcher
- [ ] `iphone_spotlight` -- opens Spotlight search
- [ ] `iphone_open_app` with app_name="Settings" -- opens Settings via Spotlight

### Perception
- [ ] `iphone_screenshot` -- captures cropped iPhone screen
- [ ] `iphone_screenshot_with_ocr` -- OCR with normalized coordinates
- [ ] `iphone_analyze_screen_now` -- Vision analysis
- [ ] `iphone_analyze_with_llm` -- CoreML LLM analysis (requires loaded model)
- [ ] `iphone_wait_for_text` with text="Settings" -- polls until text appears

### Resilience
- [ ] `iphone_reconnect` -- polls for mirroring window after disconnect

## End-to-End Scenarios

### Scenario: Open Settings and navigate
1. `iphone_launch`
2. `iphone_open_app` with app_name="Settings"
3. `iphone_screenshot_with_ocr` -- verify Settings content
4. `iphone_tap` at "General" coordinates from OCR
5. `iphone_swipe` down to find "About"
6. `iphone_home`

## Verification Summary

- [ ] Total tools returned by ListTools: **65**
- [ ] All unit tests pass: `swift test`
- [ ] Release build succeeds: `swift build -c release`
