# Required Permissions Guide

MCP macOS Control requires specific system permissions to function properly. This guide explains what permissions are needed and how to grant them.

## Required Permissions

### 1. Accessibility (Required)

**Why it's needed:**
- Control mouse movements and clicks
- Send keyboard input
- Simulate key combinations

**How to grant:**
1. Open **System Settings**
2. Go to **Privacy & Security**
3. Click **Accessibility**
4. Click the **+** button
5. Navigate to and select the application running the MCP server (e.g., Terminal, Claude Desktop)
6. Ensure the checkbox next to the application is enabled

### 2. Screen Recording (Required)

**Why it's needed:**
- Capture screenshots
- Record window information
- Perform OCR on screen content

**How to grant:**
1. Open **System Settings**
2. Go to **Privacy & Security**
3. Click **Screen Recording**
4. Enable the application running the MCP server

## Testing Permissions

After granting permissions, test that they work:

### Test Accessibility
```
Use the click_screen or type_text tools
```

If you get an error, restart the application and verify the permission is enabled.

### Test Screen Recording
```
Use the take_screenshot tool
```

If you get a black screenshot or error, verify Screen Recording permission is granted.

## Common Issues

### Permission Denied Errors

**Problem:** You see "Operation not permitted" or similar errors

**Solution:**
1. Verify permissions are granted in System Settings
2. Restart the application running the MCP server
3. In some cases, you may need to remove and re-add the app in Privacy settings

### Permissions Not Appearing

**Problem:** You don't see the prompt to grant permissions

**Solution:**
1. Try using a tool that requires the permission (this triggers the prompt)
2. Manually add the application in System Settings
3. Check macOS version (requires macOS 13.0+)

### Screenshot is Black

**Problem:** Screenshots are completely black

**Solution:**
1. Grant Screen Recording permission
2. Restart the application
3. Some apps (like QuickTime during recording) prevent screen capture for security

### Window Activation Not Working

**Problem:** `activate_window` doesn't bring window to front

**Solution:**
1. Ensure Accessibility permission is granted
2. Verify the window title pattern is correct using `list_windows`
3. Try adjusting the fuzzy match threshold
4. Some system windows may not be activatable

## Security Considerations

These permissions grant significant control over your system:

- **Only grant to trusted applications**
- The MCP server runs with the privileges of the host application
- All operations are local to your Mac
- Review source code before granting permissions
- Consider creating a dedicated user account for automation tasks

## Per-Application Settings

Different host applications may need permissions separately:

- **Terminal** - If running the MCP server from command line
- **Claude Desktop** - If using as an MCP server with Claude
- **Custom App** - Any custom application running the server

Each application needs its own permission grants.

## Automation & CI/CD

For automated environments:

1. Permissions cannot be granted programmatically (macOS security)
2. You must grant permissions interactively
3. Once granted, permissions persist across app launches
4. Consider pre-configuring a system image with permissions granted

## Revoking Permissions

To revoke permissions:

1. Open **System Settings**
2. Go to **Privacy & Security**
3. Select the permission type (Accessibility or Screen Recording)
4. Disable or remove the application

The MCP server will no longer function until permissions are re-granted.

## macOS Version Differences

### macOS 13 (Ventura) and later
- All features fully supported
- Modern ScreenCaptureKit APIs used
- Enhanced security prompts

### Earlier macOS versions
- Not officially supported
- May work with reduced functionality
- Consider upgrading to macOS 13+

## Additional Resources

- [Apple Privacy & Security Guide](https://support.apple.com/guide/mac-help/control-access-to-screen-recording-mchld6aa7d23/mac)
- [Accessibility API Documentation](https://developer.apple.com/documentation/accessibility)
- [ScreenCaptureKit Documentation](https://developer.apple.com/documentation/screencapturekit)
