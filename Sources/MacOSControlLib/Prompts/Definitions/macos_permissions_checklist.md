---
name: macos_permissions_checklist
description: macOS privacy permissions this server requires, which tools depend on each, and the System Settings deep link for granting each permission.
prompt_version: 1
arguments: []
---
This server requires three macOS privacy permissions. If a tool call fails
with a permission-denied error, identify which permission applies from the
table below and open the corresponding System Settings pane.

**Accessibility** — required to read the AX tree and synthesize mouse and
keyboard events.
- Tools that require it: `click_element`, `perform_ax_action`,
  `find_elements`, `element_at_position`, `accessibility_tree`,
  `click_screen`, `double_click`, `move_mouse`, `mouse_down`, `mouse_up`,
  `drag_mouse`, `scroll`, `type_text`, `press_keys`, `key_down`, `key_up`,
  and all iPhone Mirroring tools.
- Grant via: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
- Then add the host process (Terminal, your IDE, or the packaged binary)
  to the list and toggle it on.

**Screen Recording** — required to capture pixels from the screen.
- Tools that require it: `take_screenshot`, `take_screenshot_with_ocr`,
  `analyze_screen_now`, `analyze_screen_with_llm`,
  `intelligent_screen_summary`, `start_continuous_capture`,
  `start_screen_monitoring`, `list_capturable_displays`,
  `list_capturable_windows`.
- Grant via: `x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`
- Note: macOS will prompt to re-grant after major OS updates.

**Automation** — required to send Apple events to other applications via
AppleScript.
- Tools that require it: `run_applescript`, `click_menu_item`.
- Grant via: `x-apple.systempreferences:com.apple.preference.security?Privacy_Automation`
- Automation permission is per-target-application: the first time the host
  scripts a given app, macOS will prompt for that specific pairing.

Call the `check_permissions` tool to see which permissions are currently
granted before invoking a tool that requires one. If a permission is
missing, surface the System Settings deep link to the user — the OS does
not let processes grant themselves permission.
