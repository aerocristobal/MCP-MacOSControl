---
name: ax_observer_notifications
description: The closed set of macOS Accessibility (AXObserver) notifications accepted by wait_for_ui_event, with a one-line summary of when each fires and which element shape is reported back.
prompt_version: 1
arguments: []
---
`wait_for_ui_event` subscribes to one of the following AX notifications and
resumes when it fires, the target application terminates, or the timeout
elapses (default 30s, hard cap 300s). Anything outside this list is rejected
up front with `unsupported_notification`.

| Notification | Fires when | Typical subject |
|---|---|---|
| `AXWindowCreated` | A new window appears in the target application | the application root |
| `AXUIElementDestroyed` | An element is destroyed (sheet dismissed, popover closed) | the destroyed element — attributes are cached at subscription time because reading from a dead element is undefined |
| `AXFocusedUIElementChanged` | Keyboard focus moves to a different element | the new focused element |
| `AXValueChanged` | An element's value attribute changes (text fields, sliders, steppers) | the changed element |
| `AXSelectedTextChanged` | Text selection changes inside a text element | the text container |
| `AXTitleChanged` | An element's title changes (document rename, window title swap) | the renamed element |
| `AXMainWindowChanged` | The application's main window changes | the new main window |
| `AXFocusedWindowChanged` | The application's focused window changes (e.g., Cmd-` cycles) | the new focused window |

**Routing rules of thumb:**

- For "wait until this dialog closes," subscribe to `AXUIElementDestroyed`
  on the dialog itself (pass `element_locator`). Attributes are cached at
  subscription time, so the success response identifies which dialog closed.
- For "wait until the app shows a new window," subscribe to
  `AXWindowCreated` on the application — no `element_locator` needed.
- For "wait until focus lands in the search field," subscribe to
  `AXFocusedUIElementChanged` and check the returned element's identifier.
- For "wait until the text in this field stops being empty," subscribe to
  `AXValueChanged` with an `element_locator` pinning the field.

**Concurrency:** Multiple `wait_for_ui_event` calls on the same
`(application, notification)` pair are multiplexed onto a single underlying
`AXObserver` and all resume together when the notification fires.

**Lifetime:** For watches longer than 5 minutes, subscribe to an MCP Resource
(see `macos://ui/active-window-tree`) — `wait_for_ui_event` is designed for
short, action-scoped waits and rejects timeouts above the 300s cap.
