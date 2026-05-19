@epic-6 @story-020 @documentation
Feature: App Compatibility Catalog & Living Document
  In order to maintain evidence-based compatibility claims
  As a maintainer of MCP-MacOSControl
  I want a generated catalog regenerated from integration test observations

  Background:
    Given the integration test suite (STORY-012) has run at least once
    And the per-app capability registry (STORY-019) is loaded

  Scenario: Catalog generator produces a Markdown document from integration observations
    Given the integration suite has recorded observations for at least 5 applications
    When the catalog generator runs
    Then a file "docs/APP-COMPATIBILITY.md" is produced
    And the file contains a row for each observed application
    And each row records: bundle_identifier, observed_interaction_methods, registry_expectation, macOS_version_tested, last_verified_date

  Scenario: Catalog flags discrepancies between registry expectations and observed reality
    Given the registry expects "com.example.legacyapp" to have ax_supported = true
    But the integration suite observed interaction_method "applescript" for every click against that app
    When the catalog generator runs
    Then the row for "com.example.legacyapp" includes a "discrepancy" marker
    And the catalog summary section lists the discrepancy
    And the generator returns a non-zero exit code if any persistent discrepancy is found

  Scenario: Catalog is regenerated on every successful integration run
    Given the integration suite passes on a nightly CI run
    When the CI workflow completes
    Then "docs/APP-COMPATIBILITY.md" is regenerated
    And if the regenerated content differs from the committed version the CI job fails with a diff in the log

  Scenario: Catalog includes macOS version coverage matrix
    Given integration runs have executed on macOS 13, 14, and 15
    When the catalog is generated
    Then each application row includes a per-version status column
    And the catalog summary section reports which macOS versions have been most recently exercised
    And applications not yet tested on a supported macOS version are marked "untested"

  Scenario: Catalog provides input-source data to the registry maintainer
    Given a maintainer wants to update the registry for "com.example.newapp"
    When they consult the catalog
    Then they can see at least one integration scenario's observed result
    And they can see the date of the most recent observation
    And they can see the macOS version of the most recent observation

  Scenario: Catalog handles applications removed from integration coverage gracefully
    Given the catalog previously listed "com.example.deprecatedapp"
    And no integration scenario currently exercises that app
    When the catalog generator runs
    Then the deprecatedapp row is marked "stale" after 90 days without observation
    And after 180 days without observation the row is moved to an archived section
    But the row is not deleted (operators may still query historical observations)

  Scenario: Single-run discrepancies are warnings, not build failures
    Given the integration suite observed one mismatched interaction_method for "com.example.app" in the most recent run
    But the prior two runs all matched the registry expectation
    When the catalog generator runs
    Then the discrepancy is emitted as a warning to stderr
    And the generator exits with status code 0

  Scenario: Persistent discrepancies fail the build
    Given the integration suite observed the same mismatched interaction_method for "com.example.app" in three consecutive runs
    When the catalog generator runs
    Then the discrepancy is classified as persistent
    And the generator exits with a non-zero status code
