@epic-5 @story-008 @mcp-tool
Feature: AXObserver Wait for UI Event Tool
  In order to react to UI state changes without polling
  As an AI agent
  I want wait_for_ui_event to subscribe to an AXObserver notification and return when it fires

  Background:
    Given the MCP server is running
    And accessibility permissions are granted

  Scenario: Wait resolves when a window appears
    Given "TextEdit" is open with no dialogs visible
    When the AI agent calls wait_for_ui_event with notification "AXWindowCreated" for application "TextEdit"
    And a new TextEdit window is opened by any means
    Then the tool returns a success response containing the new window's element shape
    And the response includes "schema_version": 3
    And the response includes "interaction_method": "ax_observer"

  Scenario: Wait resolves when a sheet is dismissed
    Given a Save sheet is displayed in "TextEdit"
    When the AI agent calls wait_for_ui_event with notification "AXUIElementDestroyed" targeting the sheet element
    And the sheet is dismissed
    Then the tool returns a success response
    And the response indicates the destroyed element's prior AXIdentifier

  Scenario: Wait times out if event does not occur within the specified duration
    Given "TextEdit" is open with no pending UI changes
    When the AI agent calls wait_for_ui_event with notification "AXWindowCreated" and timeout 3 seconds
    And no new window is created within 3 seconds
    Then the tool returns a structured error with error_code "wait_timeout"
    And the error details include the notification name and elapsed seconds
    But no AXObserver remains registered for the call

  Scenario: Wait resolves when focused element changes
    Given a form with multiple fields is visible in "TextEdit"
    When the AI agent calls wait_for_ui_event with notification "AXFocusedUIElementChanged" for application "TextEdit"
    And focus moves to a different field
    Then the tool returns a success response
    And the response includes the new focused element's role, title, and AXIdentifier

  Scenario: Observer is unregistered when the target application terminates mid-wait
    Given "TextEdit" is open
    And the AI agent has called wait_for_ui_event for notification "AXValueChanged" in "TextEdit" with timeout 30 seconds
    When "TextEdit" terminates before the notification fires
    Then the tool returns a structured error with error_code "target_application_terminated"
    And the error details include the terminated application's bundle identifier
    But no orphaned AXObserver or CFRunLoopSource remains in the server process

  Scenario: Two concurrent waits on the same notification both resolve when it fires
    Given two AI agents have independently called wait_for_ui_event for "AXWindowCreated" in "TextEdit"
    When a new TextEdit window is opened by any means
    Then both tool calls return a success response describing the same new window
    And only one underlying AXObserver was registered for the (TextEdit, AXWindowCreated) pair
    And the underlying AXObserver is unregistered after the last waiter resolves

  Scenario: Permission denied at subscription time returns a structured error
    Given accessibility permissions have been revoked from the MCP process
    When the AI agent calls wait_for_ui_event for any notification in any application
    Then the tool returns a structured error with error_code "accessibility_permission_required"
    And no AXObserver is created
    And the error message describes how to grant accessibility permissions

  Scenario: Unsupported notification name returns a structured error
    Given "TextEdit" is open
    When the AI agent calls wait_for_ui_event with notification "AXMadeUpNotification" for application "TextEdit"
    Then the tool returns a structured error with error_code "unsupported_notification"
    And the error details list the supported notification names

  Scenario Outline: Support the documented AX notification set
    Given "TextEdit" is open
    When the AI agent calls wait_for_ui_event with notification <notification>
    And the corresponding UI event is triggered in TextEdit
    Then the tool returns a success response within the timeout
    And the response includes the element shape relevant to <notification>

    Examples:
      | notification                |
      | AXWindowCreated             |
      | AXUIElementDestroyed        |
      | AXFocusedUIElementChanged   |
      | AXValueChanged              |
      | AXSelectedTextChanged       |
      | AXTitleChanged              |
      | AXMainWindowChanged         |
      | AXFocusedWindowChanged      |
