@epic-4 @story-017 @mcp-prompts
Feature: MCP Prompts for Agent Workflows
  In order to publish reusable agent guidance from the server
  As an MCP server author
  I want to expose named prompts via the MCP Prompts primitive

  Background:
    Given the MCP server is running with Prompts support enabled

  Scenario: Server lists registered prompts
    Given the MCP server has registered the standard prompt set
    When an MCP client calls prompts/list
    Then the response includes a prompt named "interaction_hierarchy"
    And the response includes a prompt named "macos_permissions_checklist"
    And every listed prompt has a description of at least 50 characters
    And every listed prompt declares its arguments (or an empty arguments array)

  Scenario: Client retrieves the interaction hierarchy prompt
    When an MCP client calls prompts/get with name "interaction_hierarchy"
    Then the response includes a messages array with at least one message
    And the prompt content describes the four-layer hierarchy: AX semantic, AppleScript, hit-test, raw coordinate
    And the prompt content names the specific tools that implement each layer
    And the prompt's role is "user" (it is an instruction to the AI client, not a system message)

  # Locked design deviation from the story spec: this server has no tools that
  # require Input Monitoring, so the checklist covers the three permissions the
  # server actually uses (Accessibility, Screen Recording, Automation).
  Scenario: Client retrieves the macOS permissions prompt
    When an MCP client calls prompts/get with name "macos_permissions_checklist"
    Then the response describes the three permissions this server requires: Accessibility, Screen Recording, Automation
    And for each permission the response describes which tools require it
    And the response includes the System Settings deep link for granting each permission

  Scenario: Prompt with arguments substitutes them into the resolved content
    Given the prompt "click_and_verify" declares arguments [target_description, expected_state]
    When an MCP client calls prompts/get with name "click_and_verify" and arguments {target_description: "the Save button", expected_state: "the document is saved"}
    Then the resolved prompt content references "the Save button" verbatim
    And the resolved content references "the document is saved" verbatim
    And the resolved content does not contain unsubstituted placeholders like "{target_description}"

  Scenario: Prompt request with missing required argument returns a structured error
    Given the prompt "click_and_verify" declares target_description as required
    When an MCP client calls prompts/get with name "click_and_verify" and no arguments
    Then the response is an error with error_code "missing_required_argument"
    And the error details name the missing argument

  Scenario: Prompt request for an unknown name returns a structured error
    When an MCP client calls prompts/get with name "no_such_prompt"
    Then the response is an error with error_code "prompt_not_found"
    And the error details list the available prompt names

  Scenario: Prompts are versioned and the version is exposed in metadata
    When an MCP client calls prompts/list
    Then each listed prompt's metadata includes a prompt_version field
    And updating a prompt's content increments its prompt_version
    And the prompt_version is independent of the server version
