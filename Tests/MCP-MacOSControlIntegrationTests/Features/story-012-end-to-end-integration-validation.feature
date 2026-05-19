@epic-6 @story-012 @integration
Feature: End-to-End Integration Validation Suite
  In order to catch regressions across all interaction layers
  As a developer
  I want integration tests covering full agent workflows against real macOS apps

  Background:
    Given the full MCP server is running
    And macOS system accessibility is enabled for the test runner
    And the CI environment variable CI_MACOS_INTEGRATION = true
    And TextEdit, Finder, Safari, Calculator, and Script Editor are available

  # --- Round 4 scenarios (preserved, refined to current tool set) ---

  Scenario: Complete agent workflow — open, type, save a document
    Given no TextEdit documents are open
    When the AI agent executes an open / type / save workflow using
      run_applescript, wait_for_ui_event, type_text, accessibility_tree
    Then a file exists on disk under the test temp directory
    And the accessibility_tree response keeps schema_version 3
    And the elapsed wall-clock for the workflow is under 15 seconds

  Scenario: Validate interaction method selection across app types
    Given TextEdit (AX-supported) and an AX-degraded harness app are both running
    When the AI agent calls smart_interact with intent "click" against each
    Then the TextEdit call routes via interaction_method "ax_semantic"
    And the AX-degraded call routes via a fallback layer
    And both responses include a non-empty decision_log

  Scenario: Confirm no regressions in existing coordinate-based tools
    Given any open application window
    When the AI agent calls the existing click_screen tool with valid coordinates
    Then the click is delivered correctly
    And the legacy plain-text response shape remains backward-compatible with
      schema_version 2 consumers

  # --- Round 7 additions ---

  Scenario: NSWorkspace launch flow — open Calculator from a not-running state
    Given Calculator is not currently running
    When the AI agent subscribes to wait_for_app_event then activates Calculator
      then waits for its window then smart_interacts a keypad button
    Then step 1 resolves with bundle_identifier "com.apple.calculator"
    And the window appears within 5 seconds of the activate
    And the smart_interact interaction_method is "ax_semantic"

  Scenario: Failure-recovery — smart_interact falls back and reports decision_log
    Given an application whose AX tree is intentionally degraded
    When the AI agent calls smart_interact with intent "click" target "Action"
    Then the response's interaction_method is a fallback layer
    And the decision_log shows ax_semantic was attempted and skipped or failed
    And the decision_log records the elapsed milliseconds for each attempted layer
    And the total wall-clock for the call is under 3 seconds

  Scenario: iPhone Mirroring smoke test — coordinate-based path is unaffected by Epic 6 changes
    Given iPhone Mirroring is connected and calibrated on the test machine
    When the AI agent calls iphone_screenshot then iphone_tap at (0.5, 0.5)
    Then the iphone_tap response indicates success
    And the iPhone screen content has measurably changed within 2 seconds
    And no schema_version regression occurs in the iPhone tool responses

  Scenario: Mid-workflow permission revocation surfaces a structured error
    Given a workflow is in progress and has called wait_for_ui_event
    When macOS Accessibility permission is revoked from the MCP process mid-call
    Then the in-flight tool returns a structured error with error_code "accessibility_permission_required"
    And the error_code matches the code shipped under STORY-016
    And no subsequent tool call crashes the server
    And the server logs the revocation event with a structured log entry

  Scenario: Structured-error contract honored across every error path
    Given the integration suite runs the dedicated error-injection variant
    When each registered error_code from STORY-016 is forced or environment-gated
    Then every forced error response matches the structured shape { ok:false, error:{ code, message, details } } with isError true
    And the error_code matches a code registered in ErrorCodeRegistry
    And no error is returned as a bare string or with isError false
