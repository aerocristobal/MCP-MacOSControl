# Quick Start Guide

## Build and Install

```bash
git clone https://github.com/aerocristobal/MCP-MacOSControl.git
cd MCP-MacOSControl
swift build -c release
```

The executable is at `.build/release/mcp-macos-control`.

Optional: install to system path:
```bash
sudo cp .build/release/mcp-macos-control /usr/local/bin/
```

## Configure with Claude Desktop

Open `~/Library/Application Support/Claude/claude_desktop_config.json` and add:

```json
{
  "mcpServers": {
    "macos-control": {
      "command": "/path/to/MCP-MacOSControl/.build/release/mcp-macos-control"
    }
  }
}
```

Restart Claude Desktop.

## Grant Permissions

1. **Accessibility**: System Settings > Privacy & Security > Accessibility -- add Claude Desktop
2. **Screen Recording**: System Settings > Privacy & Security > Screen Recording -- add Claude Desktop

## Test It

Try these in Claude Desktop:

- "What's my screen resolution?"
- "Take a screenshot with OCR"
- "List all open windows"
- "Click at coordinates (500, 500)"

## Available Tools (65 total)

**Mouse (9):** click_screen, double_click, move_mouse, mouse_down, mouse_up, drag_mouse, scroll, get_screen_size, list_displays

**Keyboard (4):** type_text, press_keys, key_down, key_up

**Screen (2):** take_screenshot, take_screenshot_with_ocr

**Windows (2):** list_windows, activate_window

**Continuous Capture (6):** start/stop_continuous_capture, get_capture_frame, list_capturable_displays/windows/applications

**Vision (5):** classify_image, detect_objects, detect_rectangles, detect_saliency, detect_faces

**CoreML (8):** list/load/unload_coreml_model, get_model_info, generate_text_llm, analyze_screen_with_llm, intelligent_screen_summary, extract_key_info

**Realtime (4):** analyze_screen_now, start/stop_screen_monitoring, get_monitoring_results

**System (3):** check_permissions, wait_milliseconds, wait_for_text

**Accessibility (1):** accessibility_tree

**iPhone Mirroring (21):** iphone_status, iphone_launch, iphone_calibrate, iphone_tap, iphone_double_tap, iphone_long_press, iphone_swipe, iphone_scroll, iphone_type_text, iphone_clear_text, iphone_press_key, iphone_home, iphone_app_switcher, iphone_spotlight, iphone_screenshot, iphone_screenshot_with_ocr, iphone_analyze_screen_now, iphone_analyze_with_llm, iphone_open_app, iphone_wait_for_text, iphone_reconnect

## iPhone Mirroring Quick Start

Requires macOS 15 (Sequoia) with iPhone Mirroring configured.

```
1. "Launch iPhone Mirroring"           -> iphone_launch
2. "Open Settings on my iPhone"        -> iphone_open_app with app_name="Settings"
3. "Take a screenshot of my iPhone"    -> iphone_screenshot
4. "Read the iPhone screen text"       -> iphone_screenshot_with_ocr
5. "Tap on General"                    -> iphone_tap at OCR coordinates
6. "Go to iPhone home screen"          -> iphone_home
```

All iPhone coordinates use normalized 0.0-1.0 range. OCR results from `iphone_screenshot_with_ocr` return coordinates in this range, ready for direct use with `iphone_tap`.

## Environment Variables

```json
{
  "mcpServers": {
    "macos-control": {
      "command": "mcp-macos-control",
      "env": {
        "MCP_MACOS_CONTROL_LOG_LEVEL": "debug",
        "MCP_MACOS_CONTROL_MAX_INPUT_RATE": "10"
      }
    }
  }
}
```

## Next Steps

- [README.md](../README.md) -- full tool reference
- [Permissions Guide](PERMISSIONS.md) -- detailed permission setup
- [Testing Checklist](TESTING.md) -- manual test checklist
- [CoreML Integration](COREML_INTEGRATION.md) -- CoreML model guide
