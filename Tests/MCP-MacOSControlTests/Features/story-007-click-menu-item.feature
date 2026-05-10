@epic-2 @story-007 @mcp-tool
Feature: click_menu_item MCP Tool
  In order to activate application menu commands by name
  As an AI agent
  I want click_menu_item to navigate the menu bar hierarchy and trigger the target item

  Background:
    Given the MCP server is running
    And accessibility permissions are granted

  Scenario: Activate a top-level menu item
    Given "TextEdit" is the frontmost application
    When the AI agent calls click_menu_item with application "TextEdit" and path ["File", "Save"]
    Then the Save dialog appears or the file is saved
    And the tool returns a success response

  Scenario: Activate a nested submenu item
    Given "TextEdit" is the frontmost application
    When the AI agent calls click_menu_item with path ["Format", "Font", "Bold"]
    Then the selected text becomes bold
    And the tool returns a success response

  Scenario: Return error for a disabled menu item
    Given "TextEdit" is open with no text selected
    When the AI agent calls click_menu_item with path ["Edit", "Cut"]
    Then the tool returns an error with code "menu_item_disabled"
    And no cut action is performed

  Scenario: Return error when menu path is not found
    Given "TextEdit" is the frontmost application
    When the AI agent calls click_menu_item with path ["File", "NonExistentItem"]
    Then the tool returns an error with code "menu_item_not_found"
    And the error lists the valid items available at the "File" level
