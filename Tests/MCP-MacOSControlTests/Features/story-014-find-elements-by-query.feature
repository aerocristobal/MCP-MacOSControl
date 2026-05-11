@epic-3 @story-014 @mcp-tool
Feature: Find Elements by Query
  In order to locate UI elements without retrieving the entire accessibility tree
  As an AI agent
  I want find_elements to return only the nodes matching a semantic predicate

  Background:
    Given the MCP server is running
    And accessibility permissions are granted

  Scenario: Returns matching nodes by role and title substring
    Given "TextEdit" is open with a toolbar containing buttons "Bold", "Italic", "Underline"
    When the AI agent calls find_elements with application "TextEdit", role "AXButton", and title_contains "Bold"
    Then the response includes exactly one node
    And that node has role "AXButton" and title "Bold"
    And that node includes an ax_path array describing its position in the tree
    And the response does not include any non-matching siblings

  Scenario: Returns matching nodes by identifier exact match
    Given an application exposes elements with AXIdentifier "save-button" and "cancel-button"
    When the AI agent calls find_elements with identifier "save-button"
    Then the response includes one node whose identifier equals "save-button"
    And no node with identifier "cancel-button" is included

  Scenario: Each result includes its AX path for disambiguation
    Given two windows in "TextEdit" each contain an "AXButton" titled "Close"
    When the AI agent calls find_elements with role "AXButton" and title "Close" in application "TextEdit"
    Then the response includes two nodes
    And each node's ax_path begins with "AXApplication[TextEdit]" and includes its parent AXWindow with that window's title

  Scenario: Empty result for query with no matches is not an error
    Given "TextEdit" is open
    And no element with title "GhostButton" exists in any window
    When the AI agent calls find_elements with title "GhostButton"
    Then the response succeeds with matches = []
    And the response includes scanned_node_count and elapsed_ms fields

  Scenario: Hard cap on max_results prevents oversized payloads
    Given an application with more than 500 buttons in its tree
    When the AI agent calls find_elements with role "AXButton" and max_results 50
    Then the response contains exactly 50 matches
    And the response includes truncated_results = true
    And the response includes a hint that the predicate matched additional nodes

  Scenario: Rejects predicates that would match every node
    When the AI agent calls find_elements with no role, no title, no identifier, no description, and no label
    Then the tool returns an error with code "predicate_too_broad"
    And no AX tree traversal is performed

  Scenario: Returns invalid_regex error when title_matches contains an invalid regex
    When the AI agent calls find_elements with title_matches "[unclosed"
    Then the tool returns an error with code "invalid_regex"
    And the error message identifies which field failed compilation
    But no AX tree traversal is performed
