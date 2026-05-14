@epic-4 @story-011 @mcp-protocol
Feature: MCP Tool Annotations and Descriptions
  In order to allow AI clients to reason safely about tool invocation
  As an MCP server author
  I want every tool definition to include behavioral annotations and a rich description

  Background:
    Given the MCP server is running and has completed tool registration

  Scenario: Read-only tools declare readOnlyHint = true
    Given the MCP server has registered the accessibility_tree tool
    When an MCP client requests the tool list
    Then the accessibility_tree tool definition includes readOnlyHint = true
    And the description explains it reads but does not modify UI state

  Scenario: Destructive tools declare destructiveHint = true
    Given the MCP server has registered the run_applescript tool
    When an MCP client requests the tool list
    Then the run_applescript tool definition includes destructiveHint = true
    And the description explains that scripts can modify application and file system state

  Scenario: Every registered tool has annotations populated
    Given the MCP server has registered every tool from every module
    When an MCP client requests the tool list
    Then no tool in the list has an empty Tool.Annotations
    And every tool has at least readOnlyHint and destructiveHint set explicitly

  Scenario: All tool descriptions meet the quality bar
    Given the MCP server has registered all tools
    When an MCP client requests the tool list
    Then every tool description is at least 50 characters long
    And no description contains placeholder text such as TODO or FIXME

  Scenario: Tool schemas declare required vs optional parameters
    Given any MCP tool with required parameters
    When an MCP client inspects its JSON schema
    Then the required parameters are listed in the schema's "required" array

  Scenario: Enumerated parameter values are constrained in the schema
    Given any tool whose parameter accepts a fixed set of values
    When an MCP client inspects the parameter's JSON schema
    Then the schema declares an "enum" array listing the allowed values

  Scenario: idempotentHint is set for tools that are safe to retry
    Given the MCP server has registered idempotent read tools
    When an MCP client inspects each tool's annotations
    Then idempotentHint = true is present on read-only idempotent tools
    And tools that are not safe to retry set idempotentHint to false

  Scenario Outline: Correct annotation for each tool category
    Given the MCP server has registered the <tool_name> tool
    When an MCP client inspects its definition
    Then readOnlyHint is <read_only>
    And destructiveHint is <destructive>

    Examples: AX read tools
      | tool_name              | read_only | destructive |
      | accessibility_tree     | true      | false       |
      | element_at_position    | true      | false       |
      | find_elements          | true      | false       |

    Examples: AX interaction tools
      | tool_name              | read_only | destructive |
      | click_element          | false     | true        |
      | perform_ax_action      | false     | true        |

    Examples: Capture and inspection
      | tool_name              | read_only | destructive |
      | take_screenshot        | true      | false       |
      | get_screen_size        | true      | false       |

    Examples: Direct input
      | tool_name              | read_only | destructive |
      | click_screen           | false     | true        |
      | type_text              | false     | false       |
      | press_keys             | false     | false       |

    Examples: AppleScript bridge
      | tool_name              | read_only | destructive |
      | run_applescript        | false     | true        |
      | click_menu_item        | false     | true        |
