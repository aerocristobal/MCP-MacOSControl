# MCP macOS Control

A native macOS MCP (Model Context Protocol) server built in Swift that provides **65 tools** for comprehensive computer control — mouse, keyboard, screen capture, OCR, window management, Vision analysis, CoreML intelligence, accessibility tree reading, and **iPhone Mirroring automation** via macOS Sequoia.

[![CI](https://github.com/aerocristobal/MCP-MacOSControl/actions/workflows/ci.yml/badge.svg)](https://github.com/aerocristobal/MCP-MacOSControl/actions/workflows/ci.yml)

## Overview

MCP macOS Control enables AI agents to perceive and interact with macOS applications and, through iPhone Mirroring, iOS apps on a connected iPhone. All processing happens on-device using native Apple frameworks.

**Key capabilities:**
- Full mouse and keyboard automation via CoreGraphics events
- Screen capture with OCR text extraction (Vision framework)
- iPhone Mirroring control with normalized coordinates (macOS 15+)
- Accessibility tree reading via AXUIElement API
- On-device CoreML LLM inference (zero cloud tokens)
- Real-time screen monitoring with continuous capture
- Multi-display support
- Rate limiting, structured logging, and CI/CD

## Requirements

- macOS 13.0 (Ventura) or later (macOS 15 for iPhone Mirroring)
- Apple Silicon or Intel Mac (Apple Silicon recommended)
- Swift 5.9+ / Xcode 16+
- MCP SDK 0.12.0+

## Installation

```bash
git clone https://github.com/aerocristobal/MCP-MacOSControl.git
cd MCP-MacOSControl
swift build -c release
```

The executable is at `.build/release/mcp-macos-control`.

### Claude Desktop Configuration

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "macos-control": {
      "command": "/path/to/MCP-MacOSControl/.build/release/mcp-macos-control"
    }
  }
}
```

## Permissions

macOS requires explicit permissions:

1. **Accessibility** (System Settings > Privacy & Security > Accessibility) -- required for mouse, keyboard, window activation, and accessibility tree
2. **Screen Recording** (System Settings > Privacy & Security > Screen Recording) -- required for screenshots, OCR, and continuous capture

See [docs/PERMISSIONS.md](docs/PERMISSIONS.md) for detailed setup.

## Tools (65 total, 11 modules)

### Mouse Control (MouseModule -- 9 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `click_screen` | Click at coordinates (left/right/middle) | x, y |
| `double_click` | Double-click at coordinates | x, y |
| `move_mouse` | Move cursor | x, y |
| `mouse_down` | Hold mouse button | -- |
| `mouse_up` | Release mouse button | -- |
| `drag_mouse` | Drag between two points | from_x, from_y, to_x, to_y |
| `scroll` | Scroll in a direction | direction |
| `get_screen_size` | Get screen resolution | -- |
| `list_displays` | List all connected displays | -- |

### Keyboard Control (KeyboardModule -- 4 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `type_text` | Type text at cursor | text |
| `press_keys` | Key combos (e.g., `[["cmd", "c"]]`) | keys |
| `key_down` | Hold a key | key |
| `key_up` | Release a key | key |

### Screen Capture and OCR (ScreenCaptureModule -- 2 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `take_screenshot` | Capture screen or window as PNG | -- |
| `take_screenshot_with_ocr` | Screenshot + text extraction | -- |

### Window Management (WindowModule -- 2 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `list_windows` | List all open windows | -- |
| `activate_window` | Bring window to foreground | title_pattern |

### Continuous Capture (ContinuousCaptureModule -- 6 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `start_continuous_capture` | Start real-time capture | capture_type |
| `stop_continuous_capture` | Stop capture session | -- |
| `get_capture_frame` | Get latest frame | -- |
| `list_capturable_displays` | List available displays | -- |
| `list_capturable_windows` | List capturable windows | -- |
| `list_capturable_applications` | List running apps | -- |

### Vision Analysis (VisionModule -- 5 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `classify_image` | Scene/object classification | image_data |
| `detect_objects` | Object detection with bounding boxes | image_data |
| `detect_rectangles` | Rectangle/UI element detection | image_data |
| `detect_saliency` | Attention region detection | image_data |
| `detect_faces` | Face detection | image_data |

### CoreML Intelligence (CoreMLModule -- 8 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `list_coreml_models` | List available models | -- |
| `load_coreml_model` | Load model for inference | name, path |
| `unload_coreml_model` | Unload model | name |
| `get_model_info` | Model metadata | name |
| `generate_text_llm` | On-device text generation | model_name, prompt |
| `analyze_screen_with_llm` | Screen + Vision + LLM | model_name, instruction |
| `intelligent_screen_summary` | NLP-based screen summary | -- |
| `extract_key_info` | Extract entities from OCR | ocr_results |

### Real-Time Analysis (RealtimeModule -- 4 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `analyze_screen_now` | Quick capture + Vision analysis | -- |
| `start_screen_monitoring` | Continuous analysis | -- |
| `get_monitoring_results` | Latest analysis results | -- |
| `stop_screen_monitoring` | Stop monitoring | -- |

### System (SystemModule -- 3 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `check_permissions` | Check Accessibility and Screen Recording | -- |
| `wait_milliseconds` | Pause execution | milliseconds |
| `wait_for_text` | Poll OCR until text appears | text |

### Accessibility (AccessibilityModule -- 1 tool)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `accessibility_tree` | Read AXUIElement tree of macOS app | -- |

Returns structured JSON with role, title, value, position, size, and children for each UI element. Configurable `max_depth` (default 3). Note: works for macOS apps only -- iPhone Mirroring content requires `iphone_screenshot_with_ocr`.

### iPhone Mirroring (IPhoneMirroringModule -- 21 tools)

Requires macOS 15 (Sequoia) with iPhone Mirroring configured. All coordinates use normalized 0.0-1.0 range relative to the iPhone screen content area.

| Tool | Description | Required Params |
|------|-------------|----------------|
| `iphone_status` | Check mirroring status and connection | -- |
| `iphone_launch` | Launch/activate iPhone Mirroring | -- |
| `iphone_calibrate` | Force content rect re-calibration | -- |
| `iphone_tap` | Tap at normalized coordinates | x, y |
| `iphone_double_tap` | Double-tap | x, y |
| `iphone_long_press` | Long-press with duration | x, y |
| `iphone_swipe` | Swipe with ease-in-out curve | start_x, start_y, end_x, end_y |
| `iphone_scroll` | Scroll wheel events | -- |
| `iphone_type_text` | Paste text via clipboard | text |
| `iphone_clear_text` | Select all + delete | -- |
| `iphone_press_key` | Send key event | key |
| `iphone_home` | Go to home screen (Cmd+1) | -- |
| `iphone_app_switcher` | Open App Switcher (Cmd+2) | -- |
| `iphone_spotlight` | Open Spotlight (Cmd+3) | -- |
| `iphone_screenshot` | Capture iPhone screen content | -- |
| `iphone_screenshot_with_ocr` | Screenshot + OCR (normalized coords) | -- |
| `iphone_analyze_screen_now` | Vision analysis on iPhone screen | -- |
| `iphone_analyze_with_llm` | iPhone screen + CoreML LLM | model_name, instruction |
| `iphone_open_app` | Open iOS app by name via Spotlight | app_name |
| `iphone_wait_for_text` | Poll iPhone OCR for text | text |
| `iphone_reconnect` | Wait for mirroring reconnection | -- |

**How iPhone Mirroring works:** The server detects the iPhone Mirroring window, calibrates the iPhone screen content area via Vision rectangle detection, and translates normalized coordinates to absolute screen coordinates. Swipe gestures use ease-in-out easing with an initial nudge to ensure iOS gesture recognition. Text input uses clipboard paste for universal language support.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MCP_MACOS_CONTROL_LOG_LEVEL` | `warn` | Log level: error, warn, info, debug, trace |
| `MCP_MACOS_CONTROL_MAX_INPUT_RATE` | `10` | Maximum input events per second |

## Architecture

```
Sources/
  MacOSControlLib/                   # Library target
    ToolModule.swift                 # ToolModule protocol
    ToolRouter.swift                 # Module registry + dispatch
    Errors.swift                     # MCPError structured errors
    Logger.swift                     # Structured logging
    RateLimiter.swift                # Token bucket rate limiter
    MouseControl.swift               # CGEvent mouse automation
    KeyboardControl.swift            # CGEvent keyboard automation
    ScreenCapture.swift              # Screenshot capture
    OCRProcessor.swift               # Vision OCR
    WindowManagement.swift           # Window list/activate
    VisionAnalyzer.swift             # Vision framework analysis
    CoreMLManager.swift              # CoreML model management
    ContinuousCaptureManager.swift   # ScreenCaptureKit streams
    RealtimeAnalyzer.swift           # Continuous vision analysis
    Accessibility/
      AccessibilityTreeReader.swift  # AXUIElement tree walker
    IPhoneMirroring/
      MirroringWindowDetector.swift  # Window detection + focus guard
      CoordinateTranslator.swift     # Content rect calibration + coord translation
      GestureEngine.swift            # Tap, swipe, scroll gestures
      IOSNavigation.swift            # Home, Spotlight, App Switcher, open app
      IPhoneTextInput.swift          # Clipboard paste, key events
    Modules/
      MouseModule.swift              # 9 mouse tools
      KeyboardModule.swift           # 4 keyboard tools
      ScreenCaptureModule.swift      # 2 capture tools
      WindowModule.swift             # 2 window tools
      ContinuousCaptureModule.swift  # 6 continuous capture tools
      VisionModule.swift             # 5 vision tools
      CoreMLModule.swift             # 8 CoreML tools
      RealtimeModule.swift           # 4 realtime tools
      SystemModule.swift             # 3 system tools
      AccessibilityModule.swift      # 1 accessibility tool
      IPhoneMirroringModule.swift    # 21 iPhone tools
  MCP-MacOSControl/
    Server.swift                     # Entry point (33 lines)
Tests/
  MCP-MacOSControlTests/            # 178 unit tests
```

## Development

```bash
swift build           # Debug build
swift build -c release # Release build
swift test            # Run 178 unit tests
```

CI runs on every push via GitHub Actions (macOS 15, build + test).

## Documentation

- [Quick Start Guide](docs/QUICKSTART.md)
- [Permissions Guide](docs/PERMISSIONS.md)
- [Testing Checklist](docs/TESTING.md)
- [CoreML Integration](docs/COREML_INTEGRATION.md)
- [Product Requirements](docs/PRD-MCP-MacOSControl.md)

## License

MIT License

## Acknowledgments

- Built with the [Model Context Protocol](https://modelcontextprotocol.io) Swift SDK
- Uses Apple's native frameworks (CoreGraphics, Vision, CoreML, ScreenCaptureKit, AppKit)
