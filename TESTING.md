# MCP-MacOSControl — Manual Integration Test Checklist

Post-refactor regression testing. All 39 tools should behave identically to pre-refactor.

## Prerequisites

- [ ] `swift build` succeeds
- [ ] `swift test` — all tests pass
- [ ] Server running in Claude Desktop or MCP client

## Mouse Tools (MouseModule — 6 tools)

- [ ] `click_screen` — click at specific coordinates
- [ ] `move_mouse` — move cursor to coordinates
- [ ] `mouse_down` — hold left button
- [ ] `mouse_up` — release left button
- [ ] `drag_mouse` — drag between two points
- [ ] `get_screen_size` — returns screen dimensions

## Keyboard Tools (KeyboardModule — 4 tools)

- [ ] `type_text` — type text into focused field
- [ ] `press_keys` — key combination (e.g., `[["cmd", "c"]]`)
- [ ] `key_down` — hold a key
- [ ] `key_up` — release a key

## Screenshot & OCR (ScreenCaptureModule — 2 tools)

- [ ] `take_screenshot` — full screen capture returns PNG
- [ ] `take_screenshot_with_ocr` — screenshot + text extraction with bounding boxes

## Window Management (WindowModule — 2 tools)

- [ ] `list_windows` — returns JSON array of windows
- [ ] `activate_window` — brings matching window to foreground

## Continuous Capture (ContinuousCaptureModule — 6 tools)

- [ ] `start_continuous_capture` — starts capture session
- [ ] `get_capture_frame` — returns latest frame as PNG
- [ ] `stop_continuous_capture` — stops session
- [ ] `list_capturable_displays` — lists available displays
- [ ] `list_capturable_windows` — lists capturable windows
- [ ] `list_capturable_applications` — lists running apps

## Vision Analysis (VisionModule — 5 tools)

- [ ] `classify_image` — returns classification labels
- [ ] `detect_objects` — returns bounding boxes
- [ ] `detect_rectangles` — detects UI elements
- [ ] `detect_saliency` — returns attention regions
- [ ] `detect_faces` — returns face bounding boxes

## CoreML & Intelligence (CoreMLModule — 8 tools)

- [ ] `list_coreml_models` — lists models (may be empty)
- [ ] `load_coreml_model` — loads a model by path
- [ ] `unload_coreml_model` — unloads a model
- [ ] `get_model_info` — returns model metadata
- [ ] `generate_text_llm` — generates text from prompt
- [ ] `analyze_screen_with_llm` — vision + LLM analysis
- [ ] `intelligent_screen_summary` — NLP-based summary
- [ ] `extract_key_info` — extracts entities from OCR

## Real-Time Analysis (RealtimeModule — 4 tools)

- [ ] `analyze_screen_now` — one-shot screen analysis
- [ ] `start_screen_monitoring` — starts continuous analysis
- [ ] `get_monitoring_results` — returns latest results
- [ ] `stop_screen_monitoring` — stops monitoring

## System (SystemModule — 2 tools)

- [ ] `check_permissions` — reports Accessibility & Screen Recording status
- [ ] `wait_milliseconds` — pauses for specified duration

## Verification Summary

- [ ] Total tools returned by ListTools: **39**
- [ ] No tool names changed
- [ ] No parameter schemas changed
- [ ] Server.swift is under 50 lines (target: 33)
