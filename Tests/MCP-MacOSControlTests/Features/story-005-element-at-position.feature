@epic-1 @story-005 @mcp-tool
Feature: Element At Position Hit-Test Tool
  In order to validate visual targets before acting on them
  As an AI agent
  I want element_at_position to return the AX element at a screen coordinate

  Background:
    Given the MCP server is running
    And accessibility permissions are granted

  Scenario: Returns element details for a coordinate within a button
    Given a "Save" button is visible at approximately coordinates (400, 300)
    When the AI agent calls element_at_position with x=400 and y=300
    Then the tool returns an element with role "AXButton"
    And the element's title or label contains "Save"
    And the response includes the element's frame (position + size)

  Scenario: Returns element details for a coordinate within a text field
    Given a text field labeled "Search" is visible at coordinates (200, 150)
    When the AI agent calls element_at_position with x=200 and y=150
    Then the tool returns an element with role "AXTextField"
    And the response includes the element's settable = true flag

  Scenario: Returns background element when coordinate is over an empty area
    Given coordinates (10, 10) are in the desktop background with no foreground UI element
    When the AI agent calls element_at_position with x=10 and y=10
    Then the tool returns an element with role "AXApplication"
    And the response includes a note that no interactive element was found at those coordinates

  Scenario: Returns error when coordinates are outside any attached display
    Given a single 1920x1080 display is attached at origin (0, 0)
    When the AI agent calls element_at_position with x=5000 and y=5000
    Then the tool returns an error with code "coordinates_out_of_bounds"
    And the error includes the bounding rectangle of all attached displays

  Scenario: Returns error when coordinates are not finite
    When the AI agent calls element_at_position with x=NaN and y=0
    Then the tool returns an error with code "invalid_coordinates"
    But no AX hit-test is performed
