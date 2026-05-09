@epic-1 @story-001 @foundation
Feature: AX Element Resolver Service
  In order to enable all semantic accessibility interactions
  As an MCP tool author implementing the accessibility layer
  I want a shared AXElementResolver that finds UI elements by semantic attributes

  Background:
    Given the MCP server is running on the local macOS workstation
    And accessibility permissions have been granted to the MCP process

  Scenario: Resolve element by exact accessibility role and title
    Given the application "TextEdit" is open with a window titled "Untitled"
    When the resolver is asked for an element with role "AXButton" and title "Close"
    Then an AXUIElement reference is returned
    And the element's AXRole attribute equals "AXButton"
    And the element's AXTitle attribute equals "Close"

  Scenario: Resolve element by accessibility identifier
    Given a running application exposes an element with identifier "com.app.save-button"
    When the resolver is asked for an element with identifier "com.app.save-button"
    Then an AXUIElement reference is returned that matches that identifier

  Scenario: Return structured error when element is not found
    Given no element with role "AXButton" and title "NonExistent" exists in any open window
    When the resolver is asked for an element with role "AXButton" and title "NonExistent"
    Then an AXNotFoundError is returned
    And the error includes the search criteria that produced no match
    But no crash or unhandled exception occurs

  Scenario: Resolve element scoped to a specific application
    Given "TextEdit" and "Safari" are both open
    And both applications have a button with title "Close"
    When the resolver is asked for an element with role "AXButton" and title "Close" in application "TextEdit"
    Then the returned element belongs to the "TextEdit" process

  Scenario Outline: Handle resolution across supported element attribute types
    Given a running application with a visible element matching <attribute_type> = <value>
    When the resolver is asked to find an element by <attribute_type> with value <value>
    Then an AXUIElement is returned
    And its <attribute_type> matches <value>

    Examples:
      | attribute_type | value             |
      | AXRole         | AXTextField       |
      | AXTitle        | "Username"        |
      | AXIdentifier   | "login-field"     |
      | AXLabel        | "Search"          |
      | AXDescription  | "Close window"    |
