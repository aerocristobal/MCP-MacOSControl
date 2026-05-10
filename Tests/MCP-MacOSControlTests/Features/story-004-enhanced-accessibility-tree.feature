@epic-3 @story-004 @mcp-tool @schema-additive
Feature: Enhanced Accessibility Tree Tool
  In order to understand UI structure and affordances in one call
  As an AI agent
  I want accessibility_tree to return role, title, identifier, actions, enabled state, and settable state per node

  Background:
    Given the MCP server is running
    And accessibility permissions are granted

  Scenario: Tree includes action names for interactive elements
    Given "TextEdit" is open with a toolbar containing a "Bold" button
    When the AI agent calls accessibility_tree for application "TextEdit"
    Then the response includes a node with role "AXButton" and title "Bold"
    And that node's actions list contains "AXPress"

  Scenario: Tree marks disabled elements with enabled = false
    Given "TextEdit" is open with no text selected
    And the "Cut" menu item is disabled
    When the AI agent calls accessibility_tree for application "TextEdit"
    Then the node representing "Cut" includes enabled = false

  Scenario: Tree includes AXIdentifier when available
    Given an application exposes elements with AXIdentifier attributes
    When the AI agent calls accessibility_tree for that application
    Then nodes with AXIdentifier values include an "identifier" field in the response

  Scenario: Tree includes settable flag for text fields and sliders
    Given a dialog contains a text field and a slider
    When the AI agent calls accessibility_tree for the dialog's application
    Then the text field node includes settable = true
    And the slider node includes settable = true

  Scenario: Tree supports depth limiting to prevent oversized payloads
    Given an application with a deeply nested AX tree (depth > 20)
    When the AI agent calls accessibility_tree with max_depth = 5
    Then the response contains no nodes deeper than 5 levels from the root
    And the response includes a truncated = true flag at pruned branch points

  Scenario: Pre-existing fields remain unchanged for backward compatibility
    Given a caller written against the original accessibility_tree schema
    When the AI agent calls accessibility_tree for any application
    Then the response includes role, label, value, position, and size for every node
    And the new fields (actions, enabled, settable, identifier, truncated) are present additively
    And no previously-present field has been renamed or removed
