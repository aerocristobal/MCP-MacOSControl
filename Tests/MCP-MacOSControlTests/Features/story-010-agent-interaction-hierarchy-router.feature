@epic-6 @story-010 @mcp-tool @router
Feature: Agent Interaction Hierarchy Router
  In order to use the most reliable interaction method automatically
  As an AI agent
  I want smart_interact to route through AX → AppleScript → hit-test → coordinate layers in order

  Background:
    Given the MCP server is running with all Epic 1, 2, 3, 5 tools available
    And the per-app capability registry from STORY-019 is loaded

  Scenario: Route to AX semantic layer when element is accessible
    Given "TextEdit" is open with a "Bold" button that has a valid AXIdentifier
    When the AI agent calls smart_interact with intent "click" and target "Bold button in TextEdit toolbar"
    Then the interaction is performed via the AX semantic layer
    And the response includes "interaction_method": "ax_semantic"
    And the response includes "confidence" between 0.9 and 1.0
    And the response includes a decision_log entry showing ax_semantic succeeded on the first attempt

  Scenario: Fall back to AppleScript when AX layer fails
    Given an application whose target action has no AXAction binding
    But the application has a documented AppleScript dictionary entry for the action
    When the AI agent calls smart_interact with intent "open document" and target application "Script Editor"
    Then the AX layer is attempted and skipped with a documented reason
    And the interaction is performed via run_applescript
    And the response includes "interaction_method": "applescript"
    And the response's decision_log shows ax_semantic was tried, then skipped, then applescript succeeded

  Scenario: Fall back to coordinate click as last resort
    Given an application with no AX support and no AppleScript dictionary
    And a screenshot shows a clickable area at coordinates (500, 400)
    When the AI agent calls smart_interact with intent "click" and coordinates (500, 400)
    Then all higher layers are attempted and skipped or fail
    And the interaction is performed via the existing coordinate-based mouse click tool
    And the response includes "interaction_method": "coordinate_fallback"
    And the response includes a warning that coordinate-based clicks are less reliable
    And the response's decision_log lists every attempted layer with skip/fail reason

  Scenario: Record interaction layer and confidence in every response
    Given any application and any successful interaction
    When the AI agent calls smart_interact
    Then the response always includes "interaction_method"
    And the response always includes "confidence" between 0 and 1
    And the response always includes a non-empty decision_log array

  Scenario: Fall back to visual hit-test layer when AX-by-name fails but visual coordinates are provided
    Given an application with partial AX support — elements exist in the tree but lack stable identifiers or titles
    And the agent supplies visual coordinates (320, 180) from a screenshot
    When the AI agent calls smart_interact with intent "click", target description "Submit button", and coordinates (320, 180)
    Then the AX-by-name layer is attempted and fails to resolve
    Then the hit-test layer uses element_at_position to recover an AXUIElement at (320, 180)
    And the recovered element receives AXPress via perform_ax_action
    And the response includes "interaction_method": "ax_hit_test"
    And the response's decision_log records the (x, y) coordinates used by the hit-test layer

  Scenario: Type intent uses its own three-layer hierarchy
    Given "TextEdit" is open with a focused text area
    When the AI agent calls smart_interact with intent "type" and value "hello world"
    Then the AX layer attempts AXSetAttribute(AXValue, "hello world") first
    And on AX failure the AppleScript layer attempts to set the text-field value
    And on AppleScript failure the coordinate layer falls back to focusing the field and dispatching type_text
    And the response includes the layer that succeeded
    And the response's decision_log captures the layer ordering for the type intent

  Scenario: All layers fail — return structured all_layers_failed error
    Given an application that is in a frozen or unresponsive state
    When the AI agent calls smart_interact with intent "click" and target "any button"
    And every available layer fails
    Then the tool returns a structured error with error_code "all_layers_failed"
    And the error details include the full decision_log of attempts and failure reasons
    And the error suggests retry strategies (different intent, wait_for_app_event for unfreeze, manual fallback)

  Scenario: Capability registry skips layers known to fail for the target app
    Given the per-app capability registry marks bundle_id "com.electron.exampleapp" with ax_supported = false
    When the AI agent calls smart_interact with intent "click" target "Save in com.electron.exampleapp"
    Then the AX semantic layer is skipped without an attempt
    And the response's decision_log shows ax_semantic was skipped with reason "registry: ax_supported=false"
    And the interaction proceeds directly to the AppleScript layer

  Scenario: Decision audit log is always present, ordered, and structured
    Given any smart_interact call regardless of outcome
    When the response is returned
    Then the response includes a "decision_log" array
    And each decision_log entry has "layer", "attempted", "outcome" (one of: "succeeded", "skipped", "failed"), "reason"
    And entries are ordered by attempt time
    And the array has at least one entry even when the first layer succeeds
