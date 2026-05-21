@epic-7 @story-027 @protocol @cancellation
Feature: MCP Tool-Call Cancellation Support
  In order to abort in-flight tool calls cleanly
  As an AI agent or MCP host
  I want the server to honor notifications/cancelled and propagate cancellation

  Background:
    Given the MCP server is running with all Epic 5 wait tools and Epic 6 smart_interact

  # --- Protocol-level handling ---

  Scenario: ToolRouter accepts and routes notifications/cancelled
    Given a tool call is in flight with request_id "req-abc-123"
    When the client sends notifications/cancelled with requestId "req-abc-123"
    Then the ToolRouter routes the cancellation to the in-flight tool's cancellation handle
    And the server does not respond to the original tool call after cancellation
    And no error is sent back to the client (notifications/cancelled is fire-and-forget per MCP spec)

  Scenario: Cancellation for an unknown request_id is ignored silently
    Given no tool call is in flight with request_id "nonexistent"
    When the client sends notifications/cancelled with requestId "nonexistent"
    Then the server logs the unknown-request_id at info level
    And no error response is generated

  # --- Wait tool cancellation ---

  Scenario: Cancelling wait_for_ui_event unregisters its AXObserver subscription
    Given wait_for_ui_event is in flight for notification "AXWindowCreated" in "TextEdit"
    When notifications/cancelled fires for that request
    Then within 100ms the AXObserverManager unregisters the multiplexed subscription
    And if this was the last waiter on the (pid, notification) tuple, the underlying AXObserver is destroyed
    And no further callbacks fire for the cancelled request

  Scenario: Cancelling wait_for_element_state halts the polling loop within one poll cycle
    Given wait_for_element_state is in flight polling at 100ms cadence
    When notifications/cancelled fires for that request
    Then within 200ms the polling loop exits
    And no further AX tree reads are performed for the cancelled request

  Scenario: Cancelling wait_for_app_event removes its NSWorkspace observer
    Given wait_for_app_event is in flight subscribed to NSWorkspaceDidLaunchApplicationNotification
    When notifications/cancelled fires for that request
    Then within 100ms the NSWorkspaceEventBridge removes the matching observer
    And shared underlying observers are kept alive only if other waiters need them

  # --- smart_interact cancellation ---

  Scenario: Cancelling smart_interact mid-layer-attempt aborts the current layer and skips remaining layers
    Given smart_interact is in flight attempting the AppleScript layer
    When notifications/cancelled fires for that request
    Then within 200ms the current AppleScript invocation is cancelled
    And no subsequent layer (hit-test, coordinate) is attempted
    And the decision_log is preserved up to the cancellation point

  Scenario: Cancelling smart_interact between layer attempts is detected immediately
    Given smart_interact has just completed the AX semantic layer with .skipped outcome
    When notifications/cancelled fires before the AppleScript layer begins
    Then the AppleScript layer is not invoked
    And the response is suppressed (no client response sent)

  # --- run_applescript cancellation ---

  Scenario: Cancelling run_applescript terminates the osascript subprocess
    Given run_applescript is executing with a script that sleeps for 60 seconds
    When notifications/cancelled fires for that request
    Then within 500ms the osascript subprocess receives SIGTERM
    And if the process does not exit within an additional 1000ms it receives SIGKILL
    And the audit record for the cancelled invocation is written with execution_outcome "cancelled"

  # --- Resource hygiene under cancellation ---

  Scenario: Cancellation while AXObserver subscription is initializing is idempotent
    Given wait_for_ui_event has been requested but the AXObserverManager has not yet completed subscription setup
    When notifications/cancelled fires for that request
    Then the subscription setup completes followed by immediate teardown
    And no AXObserver remains registered after both operations finish
    And no race condition leaves a half-initialized observer

  Scenario: Double cancellation is idempotent
    Given wait_for_ui_event is in flight
    And notifications/cancelled has already been processed for that request
    When a second notifications/cancelled arrives for the same request_id
    Then the second notification is logged at debug level and ignored
    And no error is raised

  Scenario: Server shutdown cancels every in-flight tool call
    Given five long-running tool calls are in flight
    When the server receives SIGTERM
    Then all five are cancelled via the same cancellation pathway
    And all five complete their resource teardown within 2 seconds
    And the server exits cleanly within 3 seconds total

  Scenario Outline: Every long-running tool participates in cancellation
    Given <tool> is in flight
    When notifications/cancelled fires for that request
    Then the tool's resources are released within <budget_ms> milliseconds
    And the tool's response is suppressed

    Examples:
      | tool                     | budget_ms |
      | wait_for_ui_event        | 100       |
      | wait_for_element_state   | 200       |
      | wait_for_app_event       | 100       |
      | smart_interact           | 1000      |
      | run_applescript          | 1500      |
