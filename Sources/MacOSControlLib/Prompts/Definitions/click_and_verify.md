---
name: click_and_verify
description: Workflow recipe for clicking a UI target and then confirming the resulting state — pair every state-changing click with an observable verification step.
prompt_version: 1
arguments:
  - name: target_description
    required: true
    description: Human-readable description of the element to click (e.g. "the Save button").
  - name: expected_state
    required: true
    description: The observable condition that must hold after the click (e.g. "the document is saved").
---
Click {target_description}, then verify {expected_state} before taking any
follow-up action.

Recommended steps:

1. **Locate the target.** Use `accessibility_tree` or `find_elements` to
   confirm {target_description} is present and reachable. Capture its AX
   role and title so the next step can target it semantically.

2. **Click semantically.** Prefer `click_element` with the role and title
   from step 1. Fall back to `element_at_position` plus `click_element`
   only when no AX identifier is available. Coordinate-only clicks via
   `click_screen` are a last resort — they do not survive layout shifts
   between observation and action.

3. **Verify the resulting state.** Confirm {expected_state} holds:
   - Use `wait_for_text` or `accessibility_tree` to check that the UI
     transitioned as expected.
   - For state outside the UI (file saved, message sent), prefer
     `run_applescript` to query the host application directly.

4. **Recover on failure.** If {expected_state} does not hold within the
   wait window, take a screenshot and re-resolve the target — the UI may
   have shifted, a modal may have appeared, or the click may have hit a
   stale coordinate.
