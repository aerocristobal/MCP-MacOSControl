@epic-6 @story-019 @data-layer
Feature: Per-Application Capability Registry
  In order to make smart routing decisions data-driven
  As the smart_interact router (and operators inspecting routing decisions)
  I want a registry of per-app layer capabilities loaded at server startup

  Background:
    Given the MCP server is running

  Scenario: Registry loads default entries at server startup
    When the MCP server starts
    Then the in-memory registry contains entries for at least 20 well-known macOS bundle identifiers
    And each entry records boolean flags for ax_supported, applescript_supported, hit_test_supported
    And the load completes within 200 milliseconds

  Scenario: Lookup returns layer capabilities for a known bundle identifier
    Given the registry contains an entry for "com.apple.TextEdit" with ax_supported=true, applescript_supported=true
    When the router queries the registry for bundle_id "com.apple.TextEdit"
    Then the result includes ax_supported = true
    And the result includes applescript_supported = true
    And the result includes a non-empty "source" field naming where the entry came from

  Scenario: Lookup returns "unknown" for unregistered bundle identifiers
    Given no entry exists for bundle_id "com.unknown.application"
    When the router queries the registry for bundle_id "com.unknown.application"
    Then the result indicates capabilities are unknown
    And the router treats unknown apps as optimistically supporting all layers

  Scenario: User overrides shadow default entries
    Given the default registry has "com.electron.exampleapp" with ax_supported=false
    And the user override file marks "com.electron.exampleapp" with ax_supported=true
    When the registry is reloaded with the override applied
    Then the lookup for "com.electron.exampleapp" returns ax_supported = true
    And the result's "source" field reads "user_override"
    And the original default entry remains accessible via registry.defaultEntry(for:)

  Scenario: Reject malformed override file with a clear error
    Given a user override file contains a syntactically invalid JSON entry
    When the registry attempts to load it at startup
    Then the server logs a structured error with error_code "invalid_capability_registry_override"
    And the malformed entries are skipped
    And the server starts successfully using only the default entries
    And the error message identifies the offending file path and line number when available

  Scenario: Registry exposes its contents via an MCP Resource
    Given the registry is loaded
    When an MCP client lists Resources
    Then a resource "mcp://capability-registry/contents" is available
    And reading that resource returns a JSON document with every entry, its source, and last-modified timestamp

  Scenario: Capability fields are extensible without breaking existing consumers
    Given the v1 registry schema defines fields: ax_supported, applescript_supported, hit_test_supported
    When a future v2 entry adds a new boolean field "drag_supported"
    Then existing consumers querying only v1 fields continue to function unchanged
    And the registry schema_version field reflects v2
    And the MCP Resource response includes the schema_version

  Scenario Outline: Known macOS apps have sensible default capabilities
    Given the default registry shipped with the server
    When the registry is queried for <bundle_id>
    Then the result has ax_supported = <ax>
    And the result has applescript_supported = <as>

    Examples:
      | bundle_id                      | ax    | as    |
      | com.apple.TextEdit             | true  | true  |
      | com.apple.finder               | true  | true  |
      | com.apple.Safari               | true  | true  |
      | com.apple.ScriptEditor2        | true  | true  |
      | com.microsoft.VSCode           | true  | false |
      | com.tinyspeck.slackmacgap      | true  | false |
      | com.spotify.client             | true  | false |
