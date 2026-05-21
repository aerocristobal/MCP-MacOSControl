# STORY-022 — OSCAL Component Definition & Control Implementation Statements

**Epic:** EPIC-7 · Production Hardening
**Priority:** 🔴 Critical
**Story Points:** 3
**Sprint Target:** Sprint 6 (Hardening)
**Dependencies:** 🔒 STORY-021 (SBOM as a component evidence artifact)
**Refinement Round:** 8 — Newly added during Round 8 audit. Translates SECURITY.md §7's prose control mapping into a machine-readable OSCAL artifact that compliance teams can ingest.

---

## 1. User Story Narrative

```
Story: OSCAL Component Definition & Control Implementation Statements
In order to make MCP-MacOSControl's NIST SP 800-53 control posture machine-readable and continuously verifiable
As a compliance officer assembling a System Security Plan that incorporates this server as a component
I want a CycloneDX-and-OSCAL-aware component definition (component-definition.json) committed to the repository alongside per-control implementation statements
So that this server can be assembled into an SSP via OSCAL tooling without manual transcription of the SECURITY.md prose, and so that control coverage gaps surface as missing OSCAL fields rather than human-review oversights
```

**Additional Context:** SECURITY.md §7 ("OSCAL Implementation-Layer Hooks") names NIST SP 800-53 controls — AU-2 (Event Logging), AU-3 (Content of Audit Records), SI-10 (Information Input Validation), AC-3 (Access Enforcement), AC-4 (Information Flow Enforcement), CM-7 (Least Functionality) — and maps each to specific source files. This is high-quality prose that nonetheless requires manual reading to consume. OSCAL is NIST's authoritative format for this exact purpose: an SSP author should be able to ingest the project's `component-definition.json`, get the control coverage as structured data, and assemble a downstream SSP/SAP with confidence. **The system-prompt persona explicitly notes "You build OSCAL into your projects to help automate security compliance and visibility" — this story makes good on that commitment.**

---

## 2. Acceptance Criteria (BDD Scenarios)

```gherkin
@epic-7 @story-022 @compliance @oscal
Feature: OSCAL Component Definition
  In order to integrate this server's controls into downstream SSPs without manual transcription
  As a compliance officer
  I want a machine-readable OSCAL component-definition.json committed to the repo

  Background:
    Given the project ships SECURITY.md with prose control mappings
    And NIST OSCAL CLI v2.0+ is available

  Scenario: OSCAL component definition validates against the NIST schema
    Given oscal/component-definition.json is committed
    When the OSCAL CLI validates the file with --strict
    Then validation succeeds with no errors
    And validation produces no warnings except those explicitly catalogued in oscal/known-warnings.md

  Scenario: Every control mapped in SECURITY.md §7 has an OSCAL implementation statement
    Given SECURITY.md §7 names the controls: AU-2, AU-3, SI-10, AC-3, AC-4, CM-7
    When the OSCAL component definition is queried for implemented controls
    Then each named control appears with a non-empty "implementation-status: implemented" statement
    And each statement includes the implementing-source file references from SECURITY.md
    And each statement's "description" field is at least 100 characters of meaningful prose

  Scenario: New supply-chain controls from STORY-021 are mapped
    Given STORY-021 establishes SBOM, SCA, and Dependabot
    When the OSCAL component definition is reviewed
    Then NIST SP 800-53 SR-3 (Supply Chain Controls), SR-4 (Provenance), and SR-11 (Component Authenticity) appear with implementation statements
    And each statement references the implementing CI workflow steps and policy files

  Scenario: Component definition references SBOM as evidence
    Given STORY-021 produces a CycloneDX SBOM artifact
    When the OSCAL component-definition.json is inspected
    Then it includes a "links" entry of rel "evidence" pointing to the SBOM artifact location

  Scenario: Accepted residual risks from SECURITY.md are encoded as OSCAL "alternative" implementations
    Given SECURITY.md §4.1 records the AppleScript filter bypass classes as accepted residual risk
    When the OSCAL component definition is inspected for SI-10 (Information Input Validation)
    Then a control statement of "implementation-status: planned" or "alternative" exists for the bypass classes
    And the statement's "remarks" field contains the SECURITY.md §4.1 justification and re-evaluation criteria

  Scenario: CI workflow validates the OSCAL component on every PR
    Given a PR modifies oscal/component-definition.json or any file referenced as evidence
    When the CI workflow runs
    Then the OSCAL CLI validates the component definition
    And the workflow step fails if validation fails

  Scenario: Drift between SECURITY.md controls and OSCAL statements is detected
    Given SECURITY.md §7 names control X
    But the OSCAL component definition does not implement X
    When the OSCAL coverage check runs
    Then the workflow step fails with "control_mapping_drift" naming control X
    And the failure message identifies SECURITY.md as the source claim

  Scenario Outline: Per-control evidence is traceable
    Given a control implementation statement for <control>
    When the implementation field is parsed
    Then it references at least one source file from <expected_source>
    And it references at least one test file from Tests/ that exercises that control

    Examples:
      | control | expected_source                                              |
      | AU-2    | Sources/MacOSControlLib/AppleScript/AuditRecorder.swift      |
      | AU-3    | Sources/MacOSControlLib/AppleScript/AuditRecorder.swift      |
      | SI-10   | Sources/MacOSControlLib/AppleScript/AppleScriptSecurityFilter.swift |
      | AC-3    | Sources/MacOSControlLib/AppleScript/AutomationPermissionChecker.swift |
      | AC-4    | Sources/MacOSControlLib/AppleScript/AppleScriptSecurityFilter.swift |
      | CM-7    | docs/MCP-TOOL-CATALOG-AUDIT.md                               |
```

---

## 3. Scenario Coverage Checklist

| Coverage Type | Scenario(s) | Status |
|---|---|---|
| Main success path | OSCAL validates; controls implemented | ✅ |
| Alternative success path | Supply-chain controls added; SBOM evidence linked | ✅ |
| Boundary condition | Outline of per-control source/test traceability | ✅ |
| Error / rejection path | Validation failure blocks PR; drift detection blocks PR | ✅ |
| Business rule edge case | Accepted residual risk encoded as "alternative" implementation | ✅ |

---

## 4. Three Amigos Open Questions

| # | Question | Resolution |
|---|---|---|
| Q1 | Which OSCAL version — 1.0.x, 1.1.x, 2.0? | **OSCAL 2.0 (current at audit date).** Supports `links` for evidence references, has cleaner JSON shape. Validators (NIST OSCAL CLI, oscal-deep-diff) all support 2.0. _[NEEDS CONFIRMATION]_ |
| Q2 | One component definition or multiple? | **One: `oscal/component-definition.json`.** The server is a single component from an SSP perspective. If the iPhone Mirroring surface eventually warrants separate compliance posture (TCC inheritance from a connected device), it can be split later. |
| Q3 | Which NIST 800-53 baseline — Moderate, High, FedRAMP-Moderate? | **800-53 r5 Moderate** for v1; FedRAMP-Moderate overlays added in a follow-up story if a procurement need arises. The Moderate baseline covers the controls SECURITY.md already maps. _[NEEDS CONFIRMATION]_ |
| Q4 | Should we generate the OSCAL from SECURITY.md or maintain them separately? | **Maintain separately, with drift detection.** SECURITY.md is human-narrative; OSCAL is machine-structured. A bidirectional generator is harder to maintain than two artifacts with a CI drift check. The Round 8 audit's "drift detection" scenario codifies this. |
| Q5 | Where do "accepted residual risk" statements live in OSCAL terms? | **As `implementation-status: alternative`** with `remarks` containing the justification. OSCAL doesn't have a first-class "accepted risk" status; "alternative" is the canonical workaround per NIST OSCAL examples. |
| Q6 | Validation cadence — every PR or daily? | **Every PR that modifies oscal/, SECURITY.md, or anything in `Sources/MacOSControlLib/AppleScript/` or `StructuredErrors/`.** Path-scoped trigger reduces CI noise while catching the relevant change set. _[NEEDS CONFIRMATION]_ |

---

## 5. TDD Implementation Map

| BDD Scenario | Step | Step Type | Unit Under Test | TDD Test Cases Required |
|---|---|---|---|---|
| Schema validation | When CLI validates | When | `.github/workflows/ci.yml` OSCAL step | (workflow-level, exit code) |
| All SECURITY.md controls implemented | Given controls named | Given | `OscalCoverageChecker` (new Swift CLI in Tests/) | test_everyControlInSecurityMdHasOscalStatement |
| Supply-chain controls mapped | Given STORY-021 active | Given | `OscalCoverageChecker` | test_supplyChainControls_SR3_SR4_SR11_arePresent |
| SBOM evidence link | Then "evidence" link present | Then | `OscalCoverageChecker` | test_componentDefinition_referencesSbomArtifact |
| Drift detection | Given mismatch | Given | `OscalDriftDetector` | test_drift_failsWhenSecurityMdNamesUnmappedControl, test_drift_passesWhenAllControlsAligned |
| Per-control evidence | Each control → source + test | Then | `OscalCoverageChecker` | test_implementation_referencesSourceAndTestForControl_AU2, test_implementation_referencesSourceAndTestForControl_SI10 (one per control) |

---

## 6. TDD Unit Test Scaffold

```swift
// FILE: Tests/MCP-MacOSControlTests/Compliance/OscalCoverageCheckerTests.swift
// STORY: STORY-022 — OSCAL Component Definition
// COMPONENT: OscalCoverageChecker (small Swift CLI; could be a script — Swift used for native integration with the test runner)

import XCTest
@testable import MacOSControlLib

final class OscalCoverageCheckerTests: XCTestCase {

    var checker: OscalCoverageChecker!

    override func setUp() {
        super.setUp()
        checker = OscalCoverageChecker(
            componentDefinitionPath: "oscal/component-definition.json",
            securityMdPath: "docs/SECURITY.md")
    }

    // MARK: - Control Coverage

    func test_everyControlInSecurityMdHasOscalStatement() throws {
        let report = try checker.report()
        XCTAssertTrue(report.missingControls.isEmpty,
                      "Controls named in SECURITY.md without OSCAL statements: \(report.missingControls)")
    }

    func test_supplyChainControls_SR3_SR4_SR11_arePresent() throws {
        let report = try checker.report()
        XCTAssertTrue(report.implementedControls.contains("sr-3"))
        XCTAssertTrue(report.implementedControls.contains("sr-4"))
        XCTAssertTrue(report.implementedControls.contains("sr-11"))
    }

    func test_componentDefinition_referencesSbomArtifact() throws {
        let definition = try checker.parsedComponentDefinition()
        let evidenceLinks = definition.links.filter { $0.rel == "evidence" }
        XCTAssertTrue(evidenceLinks.contains { $0.href.contains("sbom-cyclonedx") })
    }

    // MARK: - Per-Control Source/Test Traceability

    func test_implementation_referencesSourceAndTestForControl_AU2() throws {
        let statement = try checker.statement(for: "au-2")
        XCTAssertTrue(statement.implementing_files.contains { $0.contains("AuditRecorder.swift") })
        XCTAssertTrue(statement.test_files.contains { $0.contains("AuditRecorder") })
    }

    func test_implementation_referencesSourceAndTestForControl_SI10() throws {
        let statement = try checker.statement(for: "si-10")
        XCTAssertTrue(statement.implementing_files.contains { $0.contains("AppleScriptSecurityFilter") })
    }

    func test_implementation_referencesSourceAndTestForControl_CM7() throws {
        let statement = try checker.statement(for: "cm-7")
        XCTAssertTrue(statement.implementing_files.contains { $0.contains("MCP-TOOL-CATALOG-AUDIT.md") }
                      || statement.implementing_files.contains { $0.contains("ToolCatalogAudit") })
    }

    // MARK: - Drift Detection

    func test_drift_failsWhenSecurityMdNamesUnmappedControl() throws {
        let fakeSecurityMd = "## §7 OSCAL\n- AU-2: …\n- AU-3: …\n- SI-10: …\n- FAKE-99: …\n"
        checker = OscalCoverageChecker(
            componentDefinitionPath: "oscal/component-definition.json",
            securityMdContent: fakeSecurityMd)
        let report = try checker.report()
        XCTAssertTrue(report.missingControls.contains("fake-99"))
    }

    func test_drift_passesWhenAllControlsAligned() throws {
        let report = try checker.report()
        XCTAssertEqual(report.missingControls.count, 0)
    }

    // MARK: - Accepted Residual Risk

    func test_si10_includesAlternativeStatement_forAcceptedBypassRisk() throws {
        let statement = try checker.statement(for: "si-10")
        XCTAssertTrue(statement.hasAlternativeImplementations,
                      "SI-10 should record the AppleScript filter bypass class as an alternative implementation per SECURITY.md §4.1")
    }
}
```

---

## 7. Component Definition Skeleton

```json
// FILE: oscal/component-definition.json
// (truncated — full file generated during implementation)
{
  "component-definition": {
    "uuid": "11111111-2222-3333-4444-555555555555",
    "metadata": {
      "title": "MCP-MacOSControl Component Definition",
      "last-modified": "2026-05-19T00:00:00Z",
      "version": "1.0.0",
      "oscal-version": "1.1.2",
      "parties": [
        {
          "uuid": "...",
          "type": "organization",
          "name": "MCP-MacOSControl project maintainers"
        }
      ]
    },
    "components": [
      {
        "uuid": "...",
        "type": "software",
        "title": "MCP-MacOSControl Server",
        "description": "Native macOS MCP server exposing accessibility, AppleScript, Vision, CoreML, and iPhone Mirroring capabilities to AI agents.",
        "purpose": "Enable AI-driven macOS automation under user TCC permissions.",
        "control-implementations": [
          {
            "uuid": "...",
            "source": "https://raw.githubusercontent.com/usnistgov/oscal-content/main/nist.gov/SP800-53/rev5/json/NIST_SP-800-53_rev5_catalog.json",
            "description": "NIST SP 800-53 Rev 5 Moderate baseline implementation",
            "implemented-requirements": [
              {
                "uuid": "...",
                "control-id": "au-2",
                "description": "Event Logging. The server's AuditRecorder records every AppleScript invocation (success, failure, and filter rejection) with timestamp, script SHA-256, target apps statically extracted from `tell application` clauses, and the disposition. See Sources/MacOSControlLib/AppleScript/AuditRecorder.swift.",
                "links": [
                  { "href": "../Sources/MacOSControlLib/AppleScript/AuditRecorder.swift", "rel": "implementation" },
                  { "href": "../Tests/MCP-MacOSControlTests/AppleScript/AuditRecorderTests.swift", "rel": "verification" }
                ]
              },
              {
                "uuid": "...",
                "control-id": "si-10",
                "description": "Information Input Validation. AppleScriptSecurityFilter applies a regex denylist over script source after comment and string-literal stripping. The filter is documented as accepted-residual-risk for the bypass classes named in SECURITY.md §4.1; see the alternative implementation statement below.",
                "links": [
                  { "href": "../Sources/MacOSControlLib/AppleScript/AppleScriptSecurityFilter.swift", "rel": "implementation" }
                ],
                "statements": [
                  {
                    "statement-id": "si-10_smt.a",
                    "uuid": "...",
                    "description": "Primary denylist applied to all AppleScript source before execution.",
                    "remarks": "Accepted residual risk for bypass classes documented in docs/SECURITY.md §4.1. Re-evaluation criteria: credible Swift AST parser available, or post-incident review identifies an exploited bypass."
                  }
                ]
              }
              // ... AC-3, AC-4, AU-3, CM-7, SR-3, SR-4, SR-11
            ]
          }
        ],
        "links": [
          { "href": "../docs/SECURITY.md", "rel": "documentation" },
          { "href": "../docs/MCP-TOOL-CATALOG-AUDIT.md", "rel": "documentation" },
          { "href": "../sbom-cyclonedx.json", "rel": "evidence" }
        ]
      }
    ]
  }
}
```

---

## 8. CI Integration

### Addition to `.github/workflows/ci.yml`

```yaml
- name: Validate OSCAL component definition
  if: |
    contains(github.event.pull_request.changed_files, 'oscal/') ||
    contains(github.event.pull_request.changed_files, 'docs/SECURITY.md') ||
    contains(github.event.pull_request.changed_files, 'Sources/MacOSControlLib/AppleScript/') ||
    contains(github.event.pull_request.changed_files, 'Sources/MacOSControlLib/StructuredErrors/')
  run: |
    npx -y @usnistgov/oscal-cli@latest validate oscal/component-definition.json --strict

- name: Run OSCAL coverage check
  run: |
    swift test --filter OscalCoverageCheckerTests
```

---

## 9. Definition of Done

**OSCAL artifact**
- [ ] `oscal/component-definition.json` committed at OSCAL 1.1.2 (or 2.0 per Q1 resolution)
- [ ] Validates against the NIST OSCAL schema with --strict and no errors
- [ ] One implemented-requirement per control named in SECURITY.md §7: AU-2, AU-3, SI-10, AC-3, AC-4, CM-7
- [ ] Implemented-requirements added for STORY-021's controls: SR-3, SR-4, SR-11
- [ ] SI-10 includes an alternative-implementation statement for accepted residual risk (bypass classes)

**Evidence linkage**
- [ ] Every implementation statement includes `links` of `rel: implementation` pointing to source files
- [ ] Every implementation statement includes `links` of `rel: verification` pointing to test files
- [ ] Component-level links include `rel: documentation` (SECURITY.md, MCP-TOOL-CATALOG-AUDIT.md) and `rel: evidence` (SBOM from STORY-021)

**Drift detection**
- [ ] `OscalCoverageChecker` test target added under `Tests/MCP-MacOSControlTests/Compliance/`
- [ ] CI fails when SECURITY.md names a control with no OSCAL implementation
- [ ] CI fails when OSCAL implements a control that SECURITY.md doesn't reference (bidirectional check)

**CI integration**
- [ ] `ci.yml` step validates the OSCAL artifact on every PR that touches the relevant paths
- [ ] OSCAL CLI invocation pinned to a specific version for reproducibility

**Documentation**
- [ ] `docs/SECURITY.md` §1 updated: "The machine-readable OSCAL component definition is at `oscal/component-definition.json`"
- [ ] `docs/stories/STORY-022-oscal-component-definition.md` (this file) committed
- [ ] `oscal/README.md` explains the maintenance workflow and validation commands
- [ ] `oscal/known-warnings.md` lists OSCAL CLI warnings that are documented-known-acceptable (initial content may be empty)

---

## 10. Notes & Observations

- **Why is this a 3-pt story?** The bulk of the work is the careful per-control prose — but SECURITY.md already provides that prose. The mechanics (JSON file, CI step, validation, drift checker) are mechanical. The "thinking" cost is concentrated in mapping STORY-021's supply-chain controls and encoding the SI-10 alternative implementation correctly.
- **Why maintain SECURITY.md and OSCAL separately?** Generating one from the other creates a tight coupling that hurts both. SECURITY.md is human-narrative (it's read by reviewers); OSCAL is machine-structured (it's read by SSP-assembly tooling). The drift-detection CI step keeps them aligned without forcing a one-way generation.
- **Why include test_files as `verification` links?** OSCAL's compliance posture is stronger when verification is auditable. Linking the test file that exercises a control gives an auditor a direct path from "this control is implemented" to "this is how I'd verify the implementation." NIST SP 800-53A guidance on assessment procedures benefits.
- **Why NIST 800-53 r5 rather than FedRAMP overlays at v1?** FedRAMP overlays add ~50 controls atop the Moderate baseline. Most are addressed by Anthropic's hosting environment, not by this server's code. Adding them would dilute the signal for "controls this server actually implements." A FedRAMP overlay can be added in a follow-up story when a deployer requires it.
- **Future work surfaced but out of scope:** OSCAL System Security Plan (`system-security-plan.json`), Assessment Plan (`assessment-plan.json`), and Plan of Action & Milestones (`poam.json`) all benefit from the component definition this story produces. They're downstream SSP-assembly concerns and don't belong in a server's own repo.
