@epic-3 @story-015 @ax-shape
Feature: Extended Element State Attributes
  In order to capture full element state in a single tree read
  As an AI agent
  I want every per-node response to include focused, selected, expanded, and visibility flags

  Background:
    Given the MCP server is running
    And accessibility permissions are granted

  Scenario: Focused text field reports focused = true
    Given "TextEdit" is open with the cursor active in the document text area
    When the AI agent calls accessibility_tree for application "TextEdit"
    Then the document text area node includes focused = true
    And no other node in the response has focused = true

  Scenario: Selected list row reports selected = true
    Given a Finder window is open in list view
    And exactly one file row is currently selected
    When the AI agent calls accessibility_tree for application "Finder"
    Then exactly one AXRow node has selected = true
    And every other AXRow has selected = false

  Scenario: Expanded disclosure triangle reports expanded = true
    Given a System Settings sidebar with one expanded section
    When the AI agent calls accessibility_tree for application "System Settings"
    Then the expanded section's AXDisclosureTriangle node has expanded = true
    And collapsed disclosure triangles in the same tree have expanded = false

  Scenario: Off-screen elements report visible_in_viewport = false
    Given a long table with rows that extend beyond the visible scroll area
    When the AI agent calls accessibility_tree for that application with max_depth 8
    Then the rows currently scrolled off-screen have visible_in_viewport = false
    And the rows currently within the scroll viewport have visible_in_viewport = true

  Scenario: Window root node reports window-level state flags
    Given "TextEdit" has two windows: one frontmost and one minimized
    When the AI agent calls accessibility_tree for application "TextEdit"
    Then the frontmost window's root node has is_frontmost = true and is_minimized = false
    And the minimized window's root node has is_minimized = true and is_frontmost = false

  Scenario: New fields surface through element_at_position with the same shape
    Given the cursor is in a focused text field at coordinates (200, 150)
    When the AI agent calls element_at_position with x = 200 and y = 150
    Then the response includes focused = true
    And the response shape matches the per-node shape from accessibility_tree

  Scenario: Pre-existing fields remain unchanged for backward compatibility
    Given a caller written against the schema_version 2 accessibility_tree response
    When the AI agent calls accessibility_tree for any application
    Then role, title, value, position, size, identifier, actions, enabled, settable, truncated, and childCount fields are present with their existing semantics
    And the new fields (focused, selected, expanded, visible_in_viewport, is_main, is_minimized, is_frontmost) are added without renaming or removing existing fields
    And schema_version increments from 2 to 3
