@epic-4 @story-016 @mcp-protocol @structured-errors
Feature: Structured Error Response Contract
  In order to enable agents to build reliable retry and recovery logic
  As an MCP tool author
  I want every error response to follow a single structured JSON shape with stable codes

  This project ships errors as a wrapped JSON envelope inside the .text() content
  block: { "ok": false, "error": { "code", "message", "details"? } }. The wrapped
  form matches the existing tool helpers (ClickMenuItemTool, RunAppleScriptTool)
  and lets success responses keep their { "ok": true, ... } symmetry. Codes are
  snake_case (^[a-z][a-z0-9_]*$, max 64 chars). The ErrorCodeRegistry is bootstrapped
  at server startup and a collision (same code, different description) terminates
  the process before any request is accepted.

  Background:
    Given the MCP server is running

  Scenario: Error response is structured JSON, not a free-text string
    Given any tool that produces an error
    When the AI agent receives the error result
    Then the result has isError = true
    And the result's content includes a JSON object
    And that object has fields: ok = false and error = { code, message, details? }

  Scenario: Error codes follow snake_case convention
    Given any error response produced by any tool
    When the AI agent inspects the error.code field
    Then the value matches the regex ^[a-z][a-z0-9_]*$
    And the value is no longer than 64 characters

  Scenario: Permission-denied error includes a recovery hint in details
    Given the MCP process does not have accessibility permission
    When the AI agent triggers the accessibility_permission_required code
    Then the error response has error.code = "accessibility_permission_required"
    And error.details includes a "recovery_hint" field describing how to grant permission
    And error.details includes a "system_settings_uri" field with the deep link to the Privacy & Security pane

  Scenario: Coordinate-out-of-bounds error includes the valid bounds in details
    Given a single 1920x1080 display attached at origin (0, 0)
    When the AI agent calls element_at_position with x = 5000 and y = 5000
    Then the error response has error.code = "coordinates_out_of_bounds"
    And error.details includes a "display_bounds" field describing the valid range

  Scenario: Two tools cannot register the same error code with conflicting semantics
    Given two MCP tools attempt to register the error code "not_found" with different descriptions
    When the MCP server initializes the error registry
    Then registration of the second tool throws CollisionError
    And the collision error surfaces both registration call sites

  Scenario: Unknown internal exception produces a generic structured error
    Given a tool raises an unexpected Swift error not registered in the error code registry
    When the error reaches the MCP response boundary
    Then the response has error.code = "internal_error"
    And error.details includes a "swift_error_type" field naming the exception type
    But sensitive internal details (file paths, stack traces) are not included in the message

  Scenario: Existing MCPError cases map to the new contract without behavioral change
    Given a tool that historically returned MCPError.permissionDenied
    When the migrated tool returns the equivalent error via toStructuredResult()
    Then the response has error.code = "permission_denied"
    And the response is isError = true
    And the legacy SCREAMING_SNAKE codes no longer appear in any error response

  Scenario: Unknown tool returns a structured error with isError = true
    Given an MCP client calls a tool name that no module handles
    When ToolRouter falls through every registered module
    Then the result has isError = true (STORY-016 fix; previously isError = false)
    And the response has error.code = "unknown_tool"
