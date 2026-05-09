@epic-1 @story-002 @mcp-tool
Feature: Semantic Element Click Tool
  In order to click buttons, checkboxes, and controls by name
  As an AI agent
  I want a click_element MCP tool that resolves the element via AX tree before clicking

  Background:
    Given the MCP server is running
    And accessibility permissions are granted

  Scenario: Click a button identified by title
    Given "TextEdit" is open
    And a button with title "Bold" is visible in the toolbar
    When the AI agent calls click_element with title "Bold" and role "AXButton"
    Then the Bold formatting is applied to selected text
    And the MCP tool returns a success response with the element's AXIdentifier

  Scenario: Click a checkbox by accessibility label
    Given a preferences dialog is open with a checkbox labeled "Enable spell check"
    When the AI agent calls click_element with label "Enable spell check" and role "AXCheckBox"
    Then the checkbox state is toggled
    And the MCP tool response includes the new checked state

  Scenario: Return error when element is not visible
    Given "TextEdit" is open
    And no element with title "FakeButton" exists in any window
    When the AI agent calls click_element with title "FakeButton"
    Then the MCP tool returns an error with code "element_not_found"
    And the error message lists the search criteria used
    But no mouse click event is dispatched to the system

  Scenario: Click element in a specific application scope
    Given "TextEdit" and "Finder" are both open
    And both have a toolbar button with the same title "View"
    When the AI agent calls click_element with title "View" and application "TextEdit"
    Then only the TextEdit toolbar View button is activated
