---
name: interaction_hierarchy
description: Recommended order for choosing a macOS UI interaction tool — try AX semantic first, then AppleScript, then hit-test, and only fall back to raw coordinates when the upper layers cannot resolve the target.
prompt_version: 1
arguments: []
---
When you need to interact with a macOS UI element, choose a tool from the four
interaction layers in this order. Each layer is more brittle than the one
above; only descend when the higher layer cannot identify the target.

1. **AX semantic layer — `click_element`.**
   The first choice for any UI interaction. Targets elements by their
   accessibility attributes (role, title, identifier, label) rather than
   pixels, so it survives window moves, theme changes, and layout shifts.
   Use this whenever the element you want has a meaningful AX role or title.

2. **AppleScript layer — `run_applescript`.**
   Use when the host application exposes a scripting dictionary (Mail,
   Finder, Safari, Notes, iWork, Music, Calendar, etc.). AppleScript is
   stable across UI changes and can read state the AX tree does not expose
   (mailbox counts, document contents, playlist queues). Prefer this over
   simulating clicks for application-domain operations.

3. **Hit-test layer — `element_at_position`.**
   Use when you have a screen coordinate (often from OCR or vision) and
   need the AX element under it before deciding how to act. The inverse of
   `click_element` — resolves geometry to semantic identity so a follow-up
   action can use the semantic layer.

4. **Coordinate fallback — `click_screen`.**
   Last resort. Use only when AX and AppleScript cannot reach the target —
   typically for canvas content, games, custom-drawn UI, or applications
   that do not expose their accessibility tree. Coordinate clicks break
   when windows move or layouts change, so always pair them with
   `take_screenshot_with_ocr` or `accessibility_tree` to confirm the
   target's current position immediately before clicking.

**Routing rule of thumb:** start with `click_element`. If the AX tree does
not name the target, try `run_applescript`. If neither applies, use
`element_at_position` to resolve a coordinate to AX, then `click_element`.
Only invoke `click_screen` when every higher layer has been ruled out.

---

**Synchronizing before you interact — choose the right wait primitive:**

- **`wait_for_app_event`** — when you need an *application lifecycle*
  transition: an app launching, activating, terminating, hiding. It is
  pre-launch capable and needs no accessibility permission, so it is the
  correct way to bridge "I issued `run_applescript` to open Safari" → "Safari
  is now running and ready for AX queries." Prefer it over `wait_milliseconds`
  or screenshot-polling for any "open app → app ready" step.
- **`wait_for_ui_event`** — once the app is already running and you need an
  *in-app AX transition* (a window created, a sheet dismissed, focus moved).
  Requires the target to be AX-queryable.
- **`wait_for_element_state`** — fallback when the transition has no AX
  notification (a button becoming enabled, a spinner disappearing).

Typical chain: `wait_for_app_event launched bundle_identifier=com.apple.TextEdit`,
then `wait_for_ui_event AXWindowCreated`, then `click_element`.
