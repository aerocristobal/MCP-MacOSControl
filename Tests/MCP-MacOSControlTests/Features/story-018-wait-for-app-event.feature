@epic-5 @story-018 @mcp-tool
Feature: Wait for Application Lifecycle Event Tool
  In order to react to macOS application lifecycle changes without polling
  As an AI agent
  I want wait_for_app_event to subscribe to an NSWorkspace notification and return when it fires

  Background:
    Given the MCP server is running

  Scenario: Wait resolves when a named application launches
    Given the application "Calculator" is not currently running
    When the AI agent calls wait_for_app_event with event "launched" for bundle_id "com.apple.calculator"
    And "Calculator" is launched by any means
    Then the tool returns a success response
    And the response includes "bundle_identifier": "com.apple.calculator"
    And the response includes the launched app's pid and localized name
    And the response includes "interaction_method": "nsworkspace_observer"

  Scenario: Wait resolves when an application becomes frontmost
    Given "TextEdit" is running but is not the frontmost application
    When the AI agent calls wait_for_app_event with event "activated" for bundle_id "com.apple.TextEdit"
    And "TextEdit" is brought to the foreground
    Then the tool returns a success response
    And the response indicates "TextEdit" is now frontmost

  Scenario: Wait resolves when an application terminates
    Given "TextEdit" is running
    When the AI agent calls wait_for_app_event with event "terminated" for bundle_id "com.apple.TextEdit"
    And "TextEdit" quits
    Then the tool returns a success response
    And the response includes the terminated app's bundle identifier and exit reason if available

  Scenario: Wait resolves on the next launch when no bundle_id filter is given
    Given the AI agent omits bundle_id and uses event "launched"
    When any application is launched by any means
    Then the tool returns a success response describing that application

  Scenario: Wait times out if the lifecycle event never fires
    Given "Calculator" is not running and will not be launched within the test window
    When the AI agent calls wait_for_app_event with event "launched" bundle_id "com.apple.calculator" and timeout 2 seconds
    And no matching event fires within 2 seconds
    Then the tool returns a structured error with error_code "wait_timeout"
    And the error details include the event name, bundle_id filter, and elapsed seconds
    But no NSWorkspace observer remains registered for the call

  Scenario: Reject unsupported event name
    When the AI agent calls wait_for_app_event with event "hibernated"
    Then the tool returns a structured error with error_code "unsupported_app_event"
    And the error details list the supported event names

  Scenario: Reject malformed bundle identifier
    When the AI agent calls wait_for_app_event with event "launched" and bundle_id "not a bundle id"
    Then the tool returns a structured error with error_code "invalid_bundle_identifier"

  Scenario Outline: Support every NSWorkspace lifecycle notification
    When the AI agent calls wait_for_app_event with event <event>
    And an application triggers <event> by any means
    Then the tool returns a success response within the timeout

    Examples:
      | event       |
      | launched    |
      | activated   |
      | terminated  |
      | deactivated |
      | hidden      |
      | unhidden    |
