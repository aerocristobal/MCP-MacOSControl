@epic-5 @story-009 @mcp-tool
Feature: Element State Polling Tool
  In order to wait for UI conditions that AXObserver does not expose
  As an AI agent
  I want wait_for_element_state to poll until an element matches a state predicate

  Background:
    Given the MCP server is running
    And accessibility permissions are granted

  Scenario: Wait resolves when a button becomes enabled
    Given a form with a "Submit" button that is initially disabled
    When the AI agent calls wait_for_element_state with role "AXButton", title "Submit", and condition "enabled = true"
    And the form is completed making the Submit button enabled
    Then the tool returns a success response
    And the response includes the element shape with "enabled": true and "schema_version": 3

  Scenario: Wait resolves when an element appears in the tree
    Given a loading spinner is displayed with no content elements yet
    When the AI agent calls wait_for_element_state with role "AXList" and condition "exists = true"
    And the content list appears after loading
    Then the tool returns a success response with the list element's properties

  Scenario: Return timeout error if condition is not met
    Given a button that remains disabled throughout the test
    When the AI agent calls wait_for_element_state for that button with condition "enabled = true" and timeout 3 seconds
    Then the tool returns a structured error with error_code "state_condition_not_met"
    And the error details include the current state of the element
    And the error details include the elapsed time

  Scenario: Wait resolves when an element becomes focused
    Given a form with multiple text fields visible
    And no field is currently focused
    When the AI agent calls wait_for_element_state with role "AXTextField", title "Username", and condition "focused = true"
    And focus is moved into the Username field
    Then the tool returns a success response
    And the response includes the element shape with "focused": true

  Scenario: Wait resolves when an element disappears from the tree
    Given a "Saving…" progress indicator is visible
    When the AI agent calls wait_for_element_state with role "AXProgressIndicator" and condition "exists = false"
    And the indicator is removed when the save completes
    Then the tool returns a success response
    And the response indicates the element no longer exists

  Scenario: Wait resolves when an element's value matches a target string
    Given a status label currently displays "Connecting…"
    When the AI agent calls wait_for_element_state with role "AXStaticText" identifier "status-label" and condition "value = 'Connected'"
    And the label text changes to "Connected"
    Then the tool returns a success response
    And the response includes the element with "value": "Connected"

  Scenario: Reject malformed condition expression
    Given any application is open
    When the AI agent calls wait_for_element_state with condition "selected = banana = true"
    Then the tool returns a structured error with error_code "invalid_condition_expression"
    And the error details name the supported condition operators and fields

  Scenario Outline: Support every state field that the serializer emits
    Given an element exists matching <locator> with <field> currently <initial_value>
    When the AI agent calls wait_for_element_state for that element with condition "<field> = <target_value>"
    And the element's <field> changes to <target_value>
    Then the tool returns a success response within the timeout
    And the response includes <field> = <target_value>

    Examples:
      | locator                  | field                  | initial_value | target_value |
      | role=AXButton            | enabled                | false         | true         |
      | role=AXButton            | exists                 | false         | true         |
      | role=AXTextField         | focused                | false         | true         |
      | role=AXMenuItem          | selected               | false         | true         |
      | role=AXDisclosureTriangle| expanded               | false         | true         |
      | role=AXButton            | visible_in_viewport    | false         | true         |
      | role=AXWindow            | is_main                | false         | true         |
      | role=AXWindow            | is_minimized           | false         | true         |
      | role=AXWindow            | is_frontmost           | false         | true         |
