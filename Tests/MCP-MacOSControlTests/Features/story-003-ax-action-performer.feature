@epic-1 @story-003 @mcp-tool
Feature: AX Action Performer Tool
  In order to trigger accessibility actions beyond mouse clicks
  As an AI agent
  I want perform_ax_action to call AXUIElementPerformAction with any valid action name

  Background:
    Given the MCP server is running
    And accessibility permissions are granted

  Scenario: Perform AXPress on a button
    Given a button with title "OK" is visible in a dialog
    When the AI agent calls perform_ax_action with element title "OK", role "AXButton", and action "AXPress"
    Then the dialog is dismissed
    And the tool returns a success response

  Scenario: Perform AXShowMenu on a pop-up button
    Given a pop-up button labeled "Font" is visible
    When the AI agent calls perform_ax_action with label "Font", role "AXPopUpButton", and action "AXShowMenu"
    Then the font menu is displayed
    And the tool returns a success response

  Scenario: Return supported actions list when action is not specified
    Given a text field with identifier "search-input" is visible
    When the AI agent calls perform_ax_action with identifier "search-input" and no action
    Then the tool returns a list of supported actions for that element
    And the list includes at least "AXPress" and "AXConfirm" if applicable

  Scenario: Return error for unsupported action on element
    Given a static text label "Version: 1.0" is visible
    When the AI agent calls perform_ax_action with role "AXStaticText", title "Version: 1.0", and action "AXPress"
    Then the tool returns an error with code "action_not_supported"
    And the error includes the list of actions the element does support
    But no action is performed on the system

  Scenario Outline: Support all standard AX named actions
    Given a UI element that supports the <action> action
    When the AI agent calls perform_ax_action with action <action>
    Then the action is performed successfully

    Examples:
      | action      |
      | AXPress     |
      | AXIncrement |
      | AXDecrement |
      | AXConfirm   |
      | AXCancel    |
      | AXShowMenu  |
      | AXRaise     |
      | AXPick      |
