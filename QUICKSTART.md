# Quick Start Guide

## Build and Install

1. **Build the project:**
   ```bash
   swift build -c release
   ```

2. **The executable will be available at:**
   ```
   .build/release/mcp-macos-control
   ```

3. **Install to system path (optional):**
   ```bash
   sudo cp .build/release/mcp-macos-control /usr/local/bin/
   ```

## Configure with Claude Desktop

1. **Open Claude Desktop configuration file:**
   ```bash
   open ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

2. **Add the MCP server:**
   ```json
   {
     "mcpServers": {
       "macos-control": {
         "command": "/Users/yourusername/path/to/MCP-MacOSControl/.build/release/mcp-macos-control"
       }
     }
   }
   ```

   Or if installed to /usr/local/bin:
   ```json
   {
     "mcpServers": {
       "macos-control": {
         "command": "mcp-macos-control"
       }
     }
   }
   ```

3. **Restart Claude Desktop**

## Grant Permissions

When you first use the MCP server, macOS will prompt you to grant permissions:

1. **Accessibility Permission:**
   - System Settings → Privacy & Security → Accessibility
   - Add and enable Claude Desktop (or Terminal if running from command line)

2. **Screen Recording Permission:**
   - System Settings → Privacy & Security → Screen Recording
   - Add and enable Claude Desktop (or Terminal if running from command line)

## Test It Out

Try these commands in Claude Desktop:

- "What's my screen resolution?"
- "Take a screenshot"
- "List all open windows"
- "Type 'Hello, World!'"
- "Move the mouse to coordinates (500, 500)"

## Available Tools

The MCP server provides 15 tools:

**Mouse Control:**
- click_screen
- move_mouse
- mouse_down
- mouse_up
- drag_mouse
- get_screen_size

**Keyboard Control:**
- type_text
- press_keys
- key_down
- key_up

**Screen Capture & OCR:**
- take_screenshot
- take_screenshot_with_ocr

**Window Management:**
- list_windows
- activate_window

**Utility:**
- wait_milliseconds

## Troubleshooting

### "Operation not permitted" errors
- Ensure Accessibility and Screen Recording permissions are granted
- Restart Claude Desktop after granting permissions

### Server not appearing in Claude
- Check the path to the executable is correct
- Verify the JSON configuration is valid
- Check Claude Desktop logs for errors

### Screenshot is black
- Ensure Screen Recording permission is granted
- Some apps prevent screen capture for security reasons

## Next Steps

- See [README.md](README.md) for complete documentation
- See [PERMISSIONS.md](PERMISSIONS.md) for detailed permission setup
- Check the Tool Reference section in README for all available parameters
