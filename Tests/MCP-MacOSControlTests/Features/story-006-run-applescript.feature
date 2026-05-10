@epic-2 @story-006 @mcp-tool @security-critical
Feature: run_applescript MCP Tool
  In order to control apps via their AppleScript dictionary
  As an AI agent
  I want run_applescript to execute an AppleScript string and return structured results

  Background:
    Given the MCP server is running
    And the system permits osascript execution from the MCP process

  Scenario: Execute a simple AppleScript and return the result
    Given no special application state is required
    When the AI agent calls run_applescript with script "tell application \"Finder\" to get name of front window"
    Then the tool returns the name of the frontmost Finder window as a string result
    And the tool response includes execution duration in milliseconds

  Scenario: Execute an AppleScript that modifies application state
    Given "TextEdit" is open with an empty document
    When the AI agent calls run_applescript with script "tell application \"TextEdit\" to set text of front document to \"Hello\""
    Then the TextEdit document contains "Hello"
    And the tool returns a success response

  Scenario: Return structured error for a syntax error in the script
    Given any system state
    When the AI agent calls run_applescript with script "tell application ??? broken script"
    Then the tool returns an error with code "applescript_error"
    And the error includes the osascript error number and error message
    But no system state is modified

  Scenario: Return timeout error when script exceeds execution limit
    Given a script designed to run indefinitely
    When the AI agent calls run_applescript with that script and a timeout of 5 seconds
    Then the script execution is terminated after 5 seconds
    And the tool returns an error with code "execution_timeout"

  Scenario: Sanitize and reject scripts containing shell injection patterns
    Given any system state
    When the AI agent calls run_applescript with a script containing "do shell script"
    Then the tool returns an error with code "security_policy_violation"
    And the script is not executed

  Scenario: Detect missing automation permission for target application
    Given the MCP process does not have automation permission for "Mail"
    When the AI agent calls run_applescript with script "tell application \"Mail\" to get name"
    Then the tool returns an error with code "automation_permission_required"
    And the error names the target application "Mail"
    And the error explains how the user grants automation permission
    But osascript is not invoked
