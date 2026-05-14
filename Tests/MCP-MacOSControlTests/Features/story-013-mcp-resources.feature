@epic-4 @story-013 @mcp-resources
Feature: MCP Resources for Ambient Context
  In order to maintain UI situational awareness without repeated tool calls
  As an AI agent
  I want MCP Resources that provide the current AX tree and active app state

  Background:
    Given the MCP server is running with Resources support enabled

  Scenario: Active application resource returns current frontmost app
    Given the user has switched focus to "Safari"
    When an MCP client reads the resource "macos://ui/active-application"
    Then the resource content includes the application name "Safari"
    And includes the bundle identifier for Safari
    And includes the PID of the Safari process
    And includes the application's localized display name

  Scenario: UI tree resource returns the current AX tree for the active window
    Given "TextEdit" is the frontmost application with a document open
    When an MCP client reads the resource "macos://ui/active-window-tree"
    Then the resource content contains the AX tree for the frontmost TextEdit window
    And the tree node shape matches the per-node shape from accessibility_tree
    And the response includes schema_version matching the current AXNodeSerializer version

  Scenario: Resources update when the active application changes
    Given an MCP client has subscribed to "macos://ui/active-application"
    When the user switches focus from "TextEdit" to "Safari"
    Then the MCP client receives a resource update notification
    And the updated content reflects Safari as the active application

  Scenario: Active-window-tree resource updates when the user switches windows within the same app
    Given an MCP client has subscribed to "macos://ui/active-window-tree"
    And "TextEdit" is the frontmost application with two windows
    When the user switches focus to the other TextEdit window
    Then the MCP client receives a resource update notification
    And the updated tree content reflects the newly-focused window

  Scenario: Resource read returns no_frontmost_application error when no app has focus
    Given no application has frontmost status (e.g., during Mission Control or login screen)
    When an MCP client reads the resource "macos://ui/active-application"
    Then the read returns an error with code "no_frontmost_application"
    And the error message explains the system is in a state without a frontmost app
    But no crash or unhandled exception occurs

  Scenario: Resource read returns accessibility_permission_required error when AX permission is denied
    Given the MCP process does not have accessibility permission
    When an MCP client reads the resource "macos://ui/active-window-tree"
    Then the read returns an error with code "accessibility_permission_required"
    And the error message describes how to grant the permission

  Scenario: Subscription unsubscribe stops further update notifications
    Given an MCP client has subscribed to "macos://ui/active-application"
    When the client unsubscribes from the resource
    And the user subsequently switches applications
    Then no resource update notification is delivered to that client
    And the server's underlying NSWorkspace observer is removed when the last subscriber disconnects

  Scenario: Concurrent subscribers each receive update notifications
    Given two MCP clients have subscribed to "macos://ui/active-application"
    When the user switches applications
    Then both clients receive an update notification
    And each notification contains the same updated content
