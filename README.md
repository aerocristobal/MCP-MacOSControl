# MCP macOS Control

A native macOS MCP (Model Context Protocol) server built in Swift that provides comprehensive computer control capabilities including mouse automation, keyboard input, screen capture, OCR text extraction, window management, **continuous capture with ScreenCaptureKit**, **advanced Vision framework analysis**, and **on-device CoreML LLM processing**.

## 🆕 Latest Update

**NEW**: Added **CoreML & On-Device Intelligence** (8 new tools) - Reduce cloud API token usage by 60-90%!
- 🤖 **On-Device LLM**: Load and run CoreML language models locally (zero cloud tokens)
- 🧠 **Intelligent Analysis**: Combine screen capture + Vision + LLM reasoning in one call
- 📊 **Smart Summaries**: Extract key information using NaturalLanguage framework
- 🔒 **Privacy-First**: All processing happens on-device
- ⚡ **Fast & Free**: Leverage Neural Engine, GPU, and CPU automatically

**Previous Update**: Added **11 powerful tools** for continuous screen capture and Vision framework integration:
- ✨ **Continuous Capture**: Monitor displays, windows, or apps in real-time with ScreenCaptureKit
- 🧠 **Image Classification**: Identify objects and scenes using Vision framework
- 👁️ **Object Detection**: Detect animals and objects with bounding boxes
- 📐 **Rectangle Detection**: Find UI elements, documents, and screens
- 🎯 **Saliency Detection**: Identify attention-grabbing regions
- 👤 **Face Detection**: Locate faces with orientation data

See [COREML_INTEGRATION.md](COREML_INTEGRATION.md) for the complete CoreML guide.
See [NEW_FEATURES.md](NEW_FEATURES.md) for continuous capture & Vision features.

## Features

MCP macOS Control provides **39 powerful tools** for programmatic control of your Mac:

### Mouse Control (6 tools)
- **click_screen** - Click at specific (x, y) coordinates
- **move_mouse** - Move cursor to specified position
- **mouse_down** - Press and hold a mouse button (left/right/middle)
- **mouse_up** - Release a mouse button
- **drag_mouse** - Drag from one position to another with configurable duration
- **get_screen_size** - Get current screen resolution (width/height)

### Keyboard Control (4 tools)
- **type_text** - Type text at current cursor position
- **press_keys** - Press single keys, sequences, or combinations (e.g., Cmd+C)
- **key_down** - Hold down a specific key
- **key_up** - Release a specific key

### Screen Capture & OCR (2 tools)
- **take_screenshot** - Capture full screen or specific windows
  - Supports window pattern matching (regex or fuzzy)
  - Optional saving to downloads directory
  - Returns base64-encoded PNG data

- **take_screenshot_with_ocr** - Screenshot with text extraction using Vision framework
  - Returns list of tuples: `[coordinates, text, confidence]`
  - Provides pixel coordinates for each detected text element
  - Native macOS OCR with high accuracy

### Window Management (2 tools)
- **list_windows** - List all open windows with title, position, dimensions, and state
- **activate_window** - Bring a window to foreground by title pattern matching
  - Supports regex or fuzzy matching with configurable threshold

### Utility (1 tool)
- **wait_milliseconds** - Pause execution for specified duration

### Continuous Capture (6 tools)
- **start_continuous_capture** - Start real-time capture of displays, windows, or applications
- **stop_continuous_capture** - Stop active capture session
- **get_capture_frame** - Get latest captured frame as PNG
- **list_capturable_displays** - List all available displays
- **list_capturable_windows** - List all capturable windows (ScreenCaptureKit)
- **list_capturable_applications** - List all running applications

### Vision Framework Analysis (5 tools)
- **classify_image** - Classify objects/scenes in images
- **detect_objects** - Detect objects with bounding boxes
- **detect_rectangles** - Find rectangular shapes (UI elements, documents)
- **detect_saliency** - Identify attention-grabbing regions
- **detect_faces** - Detect faces with bounding boxes and landmarks

### CoreML & On-Device Intelligence (8 tools)
- **list_coreml_models** - List available CoreML models in MLModels directory
- **load_coreml_model** - Load a CoreML model for on-device inference
- **unload_coreml_model** - Unload model from memory
- **get_model_info** - Get metadata about loaded model
- **generate_text_llm** - Generate text using on-device LLM (zero cloud tokens!)
- **analyze_screen_with_llm** - Combine screen capture + Vision + LLM reasoning
- **intelligent_screen_summary** - Smart summary using NaturalLanguage framework
- **extract_key_info** - Extract entities and key information from OCR text

### High-Level Real-Time Analysis (4 tools)
- **analyze_screen_now** - Quick capture and analyze with computer vision
- **start_screen_monitoring** - Continuous monitoring with real-time analysis
- **get_monitoring_results** - Get latest analysis from monitoring
- **stop_screen_monitoring** - Stop active monitoring session

### System Tools (1 tool)
- **check_permissions** - Check Screen Recording and Accessibility permissions

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 14.0 or later
- Swift 5.9 or later

## Installation

### Option 1: Build from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/MCP-MacOSControl.git
cd MCP-MacOSControl
```

2. Build the project:
```bash
swift build -c release
```

3. The executable will be available at:
```bash
.build/release/mcp-macos-control
```

### Option 2: Install to System Path

After building, copy the executable to a directory in your PATH:
```bash
sudo cp .build/release/mcp-macos-control /usr/local/bin/
```

## Configuration

### Claude Desktop Integration

Add the server to your Claude Desktop configuration file:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "macos-control": {
      "command": "/path/to/mcp-macos-control"
    }
  }
}
```

Or if installed to system path:
```json
{
  "mcpServers": {
    "macos-control": {
      "command": "mcp-macos-control"
    }
  }
}
```

### Environment Variables

- **MCP_MACOS_CONTROL_SCREENSHOT_DIR** - Custom directory for saving screenshots (default: Downloads folder)

Example:
```json
{
  "mcpServers": {
    "macos-control": {
      "command": "mcp-macos-control",
      "env": {
        "MCP_MACOS_CONTROL_SCREENSHOT_DIR": "/Users/yourusername/Screenshots"
      }
    }
  }
}
```

## Permissions

macOS requires explicit permissions for system automation. When you first run the MCP server, you'll need to grant the following permissions:

1. **Accessibility** - Required for mouse and keyboard control
   - System Settings → Privacy & Security → Accessibility
   - Add and enable the terminal or application running the MCP server

2. **Screen Recording** - Required for screenshots
   - System Settings → Privacy & Security → Screen Recording
   - Add and enable the terminal or application running the MCP server

## Usage Examples

Once configured with Claude Desktop, you can use natural language commands:

### Mouse Control
```
"Click at coordinates (500, 300)"
"Move the mouse to the center of the screen"
"Drag from (100, 100) to (500, 500)"
```

### Keyboard Control
```
"Type 'Hello, World!'"
"Press Command+C to copy"
"Press Command+Tab to switch applications"
```

### Screenshots
```
"Take a screenshot of the entire screen"
"Capture the Safari window"
"Take a screenshot with OCR and extract all text"
```

### Window Management
```
"List all open windows"
"Activate the Chrome window"
"Bring the Terminal window to the front"
```

## Tool Reference

### click_screen
Click at specified screen coordinates.

**Parameters:**
- `x` (integer, required) - X coordinate
- `y` (integer, required) - Y coordinate

### get_screen_size
Get the current screen resolution.

**Returns:**
- `width` (integer) - Screen width in pixels
- `height` (integer) - Screen height in pixels

### type_text
Type the specified text at the current cursor position.

**Parameters:**
- `text` (string, required) - Text to type

### move_mouse
Move the mouse to specified screen coordinates.

**Parameters:**
- `x` (integer, required) - X coordinate
- `y` (integer, required) - Y coordinate

### mouse_down
Hold down a mouse button.

**Parameters:**
- `button` (string, optional) - Mouse button: "left", "right", or "middle" (default: "left")

### mouse_up
Release a mouse button.

**Parameters:**
- `button` (string, optional) - Mouse button: "left", "right", or "middle" (default: "left")

### drag_mouse
Drag the mouse from one position to another.

**Parameters:**
- `from_x` (integer, required) - Start X coordinate
- `from_y` (integer, required) - Start Y coordinate
- `to_x` (integer, required) - End X coordinate
- `to_y` (integer, required) - End Y coordinate
- `duration` (number, optional) - Duration in seconds (default: 0.5)

### key_down
Hold down a specific keyboard key.

**Parameters:**
- `key` (string, required) - Key to hold down

### key_up
Release a specific keyboard key.

**Parameters:**
- `key` (string, required) - Key to release

### press_keys
Press single keys, sequences, or combinations.

**Parameters:**
- `keys` (array, required) - Keys to press. Can be:
  - Single key: `["a"]`
  - Sequence: `["a", "b", "c"]`
  - Combination: `[["cmd", "c"]]`
  - Multiple combinations: `[["cmd", "c"], ["cmd", "v"]]`

**Supported Keys:**
- Letters: a-z
- Numbers: 0-9
- Function keys: f1-f12
- Modifiers: cmd/command, shift, ctrl/control, option/alt
- Special: return, enter, tab, space, delete, escape/esc, backspace
- Arrows: left, right, up, down
- Navigation: home, end, pageup, pagedown

### take_screenshot
Capture screen as base64-encoded PNG.

**Parameters:**
- `title_pattern` (string, optional) - Window title pattern to capture
- `use_regex` (boolean, optional) - Use regex for pattern matching (default: false)
- `threshold` (integer, optional) - Fuzzy match threshold 0-100 (default: 60)
- `save_to_downloads` (boolean, optional) - Save to downloads folder (default: false)

**Returns:**
- `image` (string) - Base64-encoded PNG data URI
- `width` (integer) - Image width in pixels
- `height` (integer) - Image height in pixels
- Additional window metadata if capturing specific window

### take_screenshot_with_ocr
Take screenshot and extract text with OCR using Vision framework.

**Parameters:**
- `title_pattern` (string, optional) - Window title pattern to capture
- `use_regex` (boolean, optional) - Use regex for pattern matching (default: false)
- `threshold` (integer, optional) - Fuzzy match threshold 0-100 (default: 60)
- `save_to_downloads` (boolean, optional) - Save to downloads folder (default: false)

**Returns:**
- `ocr_results` (array) - List of `[coordinates, text, confidence]` tuples
  - `coordinates` - Array of 4 corner points: `[[x1,y1], [x2,y2], [x3,y3], [x4,y4]]`
  - `text` (string) - Extracted text
  - `confidence` (float) - Confidence score 0.0-1.0
- `text_count` (integer) - Number of text elements found

### list_windows
List all open windows on the system.

**Returns:**
- `windows` (array) - List of window objects containing:
  - `windowID` (integer) - Unique window identifier
  - `title` (string) - Window title
  - `ownerName` (string) - Application name
  - `x`, `y` (integer) - Window position
  - `width`, `height` (integer) - Window dimensions
  - `layer` (integer) - Window layer/z-index
  - `isOnScreen` (boolean) - Whether window is visible
  - `alpha` (float) - Window transparency
- `count` (integer) - Total number of windows

### activate_window
Activate (bring to foreground) a window by matching its title.

**Parameters:**
- `title_pattern` (string, required) - Window title pattern
- `use_regex` (boolean, optional) - Use regex for pattern matching (default: false)
- `threshold` (integer, optional) - Fuzzy match threshold 0-100 (default: 60)

### wait_milliseconds
Wait for a specified number of milliseconds.

**Parameters:**
- `milliseconds` (integer, required) - Milliseconds to wait

## Technical Architecture

### Core Technologies
- **Swift 5.9+** - Modern, safe, and performant
- **CoreGraphics** - Low-level mouse and keyboard control via CGEvents
- **AppKit** - Native macOS window management
- **Vision Framework** - On-device OCR with high accuracy
- **ScreenCaptureKit** - Modern screen capture APIs (macOS 13+)
- **Model Context Protocol SDK** - Standard MCP server implementation

### Key Features
- **Zero External Dependencies** - Uses only native macOS frameworks
- **Async/Await** - Modern Swift concurrency for responsive operations
- **Type-Safe** - Swift's type system ensures reliability
- **Native OCR** - Uses Apple's Vision framework (no external OCR dependencies)
- **Fuzzy Window Matching** - Flexible window targeting with similarity scoring
- **Regex Support** - Precise pattern matching for advanced use cases

## Security & Privacy

This MCP server requires extensive system permissions to function. Use it responsibly:

- Only grant permissions to trusted applications
- The server runs with the same privileges as the host application
- All operations are performed locally on your Mac
- No data is sent to external servers
- Review the source code before granting permissions

## Troubleshooting

### Permission Errors
If you get errors about accessibility or screen recording:
1. Open System Settings → Privacy & Security
2. Navigate to Accessibility and Screen Recording
3. Add the application running the MCP server
4. Restart the application

### Window Not Found
If `activate_window` can't find your window:
1. Use `list_windows` to see all available windows
2. Try adjusting the `threshold` parameter (lower = more strict)
3. Use regex matching for precise pattern matching
4. Check that the window is actually on screen

### Screenshot is Black
If screenshots appear black:
1. Ensure Screen Recording permission is granted
2. Try capturing the full screen instead of a specific window
3. Some applications may prevent screen capture for security reasons

## Development

### Project Structure
```
MCP-MacOSControl/
├── Package.swift              # Swift Package Manager configuration
├── Sources/
│   └── MCP-MacOSControl/
│       ├── main.swift         # MCP server and tool registration
│       ├── MouseControl.swift # Mouse automation
│       ├── KeyboardControl.swift # Keyboard automation
│       ├── ScreenCapture.swift # Screenshot functionality
│       ├── OCRProcessor.swift  # Vision framework OCR
│       └── WindowManagement.swift # Window list/activation
└── README.md
```

### Building for Development
```bash
swift build
swift run mcp-macos-control
```

### Running Tests
```bash
swift test
```

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Acknowledgments

- Inspired by [computer-control-mcp](https://github.com/ab498/computer-control-mcp) by AB498
- Built with the [Model Context Protocol](https://modelcontextprotocol.io)
- Uses Apple's native frameworks for all functionality

## Support

For issues, questions, or feature requests:
- Open an issue on GitHub
- Check existing issues for solutions
- Review the troubleshooting section

---

**Note:** This tool provides powerful system automation capabilities. Always ensure you understand what commands will do before executing them, especially when granting control to AI assistants.
