# STORY-037 — OSCAL Assessment Results & POA&M Artifacts

**Epic:** EPIC-7 · Production Hardening
**Priority:** 🟡 High
**Story Points:** 2
**Sprint Target:** Sprint 6 (Hardening — closes SECURITY.md §7.3 roadmap items 2 & 3)
**Dependencies:** 🔒 STORY-022 (OSCAL component-definition.json provides the control identifiers these artifacts reference), 🔒 STORY-024 (audit-record schema is the source for Assessment Results observations)
**Refinement Round:** 9 — Newly added during Round 9 close-out review. STORY-022 (committed Round 8) covers OSCAL roadmap item 1 (component definition). This story covers items 2 (audit-record → OSCAL Observation mapping) and 3 (POA&M entries for §4.1 accepted risks), completing the three-artifact OSCAL roadmap stated in `docs/SECURITY.md` §7.3.

---

## 1. User Story Narrative

```
Story: OSCAL Assessment Results & POA&M Artifacts
In order to make MCP-MacOSControl's continuous-monitoring evidence machine-consumable by an SSP-author's OSCAL toolchain
As a compliance officer or assessor downstream of the system owner
I want a continuously-updated OSCAL Assessment Results document derived from the audit-record stream and a committed POA&M document for every accepted-risk statement in SECURITY.md §4
So that the project's compliance posture is verifiable from machine-readable artifacts end-to-end — control implementation (STORY-022), control evidence (this story's Assessment Results), and risk acceptance (this story's POA&M) — without an assessor needing to manually transcribe prose
```

**Additional Context:** SECURITY.md §7.3 names three OSCAL artifacts as the design-input roadmap. STORY-022 commits the first (Component Definition). The other two — (a) per-`AuditRecord` → OSCAL Assessment Results `observation` conversion, (b) POA&M entries for each accepted risk in §4 — are equally part of the persona commitment to "build OSCAL into your projects." Without them, the project's OSCAL surface stops at "what controls do we claim" and never reaches "what evidence do we have they're working" or "what residual risks have we accepted with what justification." This story closes that gap. It does **not** address the OSCAL Assessment Plan (SAP) — that is an assessor-authored artifact, not a system-owner artifact, and lives downstream.

---

## 2. Acceptance Criteria (BDD Scenarios)

```gherkin
@epic-7 @story-037 @compliance @oscal @audit
Feature: OSCAL Assessment Results & POA&M Artifacts
  In order to make compliance evidence and accepted-risk decisions machine-consumable
  As a compliance officer
  I want OSCAL Assessment Results and POA&M committed alongside the component definition

  Background:
    Given STORY-022 has shipped oscal/component-definition.json
    And STORY-024 has shipped the production audit sink with a documented AuditRecord schema
    And NIST OSCAL CLI v2.0+ is available

  # --- POA&M artifact (item 3) ---

  Scenario: POA&M document validates against the NIST OSCAL POA&M schema
    Given oscal/plan-of-action-and-milestones.json is committed
    When the OSCAL CLI validates the file with --strict
    Then validation succeeds with no errors
    And the file declares it conforms to OSCAL POA&M model version 1.1.2 or later

  Scenario: Each accepted-risk statement in SECURITY.md §4 has a corresponding POA&M item
    Given SECURITY.md §4 contains accepted-risk statements (e.g., §4.1 regex bypass classes, §4.4 deferred production audit sink before STORY-024 ships)
    When the POA&M document is queried for items with status "risk-accepted"
    Then every numbered §4 accepted-risk statement appears as a poam-item
    And each item carries the relevant control IDs as related-controls (e.g., SI-10 for §4.1, AU-9 for §4.4)
    And each item includes a non-empty risk-log describing the justification, the re-evaluation criteria, and the named owner

  Scenario: POA&M items closed by Sprint 6 hardening are marked closed with evidence
    Given §4.4 ("deferred production audit sink") was an accepted risk before Sprint 6
    And STORY-024 has shipped the production sink
    When the POA&M is queried for the §4.4 item
    Then the item's status is "closed"
    And the closure evidence cites the STORY-024 implementation and the test fixture proving the sink works

  Scenario: POA&M includes the milestone schedule for each open item
    Given an open POA&M item references the AppleScript regex filter bypass class
    When the item is inspected
    Then the item lists one or more milestones with target dates
    And at least one milestone is "STORY-025 fuzz harness operational" with a target sprint
    And the item declares the named risk owner

  # --- Assessment Results artifact (item 2) ---

  Scenario: Assessment Results document validates against the NIST OSCAL AR schema
    Given oscal/assessment-results.json is committed
    When the OSCAL CLI validates the file with --strict
    Then validation succeeds with no errors

  Scenario: Each AuditRecord type has a documented mapping to an OSCAL observation
    Given the AuditRecord schema from STORY-024 defines event types (e.g., applescript_executed, applescript_rejected, click_menu_item_invoked)
    When the assessment-results-mapping.md document is read
    Then each AuditRecord event type has a row describing which OSCAL observation type it maps to
    And the mapping cites the related-controls field that should be populated
    And the mapping cites which AuditRecord fields populate which observation fields (e.g., timestamp → collected, toolName → subjects[type=tool], outcome → assessment-objectives)

  Scenario: A continuous-monitoring run converts AuditRecord events into observations
    Given a fixture of 10 sample AuditRecord events covering applescript_executed, applescript_rejected, click_menu_item_invoked, run_applescript_audit_chain_break
    When the oscal-emit CLI is invoked with the fixture file
    Then it produces oscal/assessment-results.json containing one observation per input record
    And each observation's "subjects" identifies the tool, the target application, and the local user
    And each observation's "collected" timestamp matches the source AuditRecord timestamp
    And each observation links to the related control(s) (AU-2 + AU-3 minimum)

  Scenario: Hash-chain breaks from STORY-024 generate a higher-severity observation
    Given STORY-024 detects a hash-chain break in the audit log
    And the AuditRecord stream contains an "audit_chain_break" event
    When oscal-emit runs
    Then the generated observation has a non-empty "risks" link referencing the AU-9 control
    And the observation's "remarks" field includes the chain offset and detected mismatch
    And a POA&M item is auto-opened with status "open" referencing the observation

  Scenario: Assessment Results are continuously appended, not rewritten
    Given oscal/assessment-results.json already contains observations from prior runs
    When oscal-emit runs with new AuditRecord events
    Then new observations are appended to the "observations" array
    And no prior observation's uuid or content is modified
    And the document's metadata.last-modified timestamp updates

  # --- Drift between artifacts ---

  Scenario: PR that adds a SECURITY.md §4 accepted-risk statement requires a POA&M entry
    Given a PR modifies SECURITY.md §4 to add a new accepted-risk statement
    When CI runs the OscalDriftDetector from STORY-022 (extended for POA&M coverage)
    Then the workflow fails if no corresponding poam-item is added to oscal/plan-of-action-and-milestones.json
    And the failure message names the §4 subsection lacking POA&M coverage

  Scenario: PR that closes a §4 accepted-risk statement requires the POA&M status to flip
    Given a PR modifies SECURITY.md §4 to remove an accepted-risk statement (the risk is closed)
    When CI runs the drift detector
    Then the workflow fails if the corresponding poam-item's status is still "open" or "risk-accepted"
    And the failure message lists the items needing status updates

  # --- Tooling and discoverability ---

  Scenario: README links to all three OSCAL artifacts
    Given the OSCAL component definition, POA&M, and Assessment Results are committed
    When README.md is read
    Then it includes a "Compliance Artifacts" section
    And the section links to oscal/component-definition.json, oscal/plan-of-action-and-milestones.json, oscal/assessment-results.json
    And the section names the OSCAL model version for each

  Scenario Outline: AuditRecord event type maps to expected OSCAL observation type
    Given an AuditRecord event of type <event_type>
    When oscal-emit converts it to an OSCAL observation
    Then the observation's "methods" field is <method>
    And the observation links the controls <controls>

    Examples:
      | event_type                       | method      | controls          |
      | applescript_executed             | EXAMINE     | AU-2, AU-3, CM-7  |
      | applescript_rejected             | EXAMINE     | SI-10, CM-7       |
      | click_menu_item_invoked          | EXAMINE     | AU-2, AU-3        |
      | run_applescript_audit_chain_break| TEST        | AU-9              |
      | rate_limit_exceeded              | EXAMINE     | AC-4              |
      | response_size_truncated          | EXAMINE     | AC-4              |
```

---

## 3. Scenario Coverage Checklist

| Coverage Type | Scenario(s) | Status |
|---|---|---|
| Main success path | Validate POA&M and AR; emit observation per AuditRecord; append continuously | ✅ |
| Alternative success path | Closed risks; auto-open POA&M on chain break; README discoverability | ✅ |
| Boundary condition | Continuous append (no rewrite); first-run empty observations array | ✅ |
| Error / rejection path | Drift detector fails when SECURITY.md and POA&M diverge | ✅ |
| Business rule edge case | Hash-chain break elevates observation severity and auto-opens POA&M; mapping outline covers six event types | ✅ |

---

## 4. Three Amigos Open Questions

| # | Question | Resolution |
|---|---|---|
| Q1 | Is `oscal/assessment-results.json` checked into git or generated on demand? | **Generated and committed on every push to `main`.** Committing the file makes it discoverable and bounds growth (CI prunes observations older than 90 days at commit time, retaining a rolling window). On-demand-only would mean assessors can't see history without re-running the pipeline. _[NEEDS CONFIRMATION on the 90-day retention window — could be 30, 180, or 365 depending on the compliance regime.]_ |
| Q2 | Where does the `oscal-emit` CLI live — in this repo, a separate tool, or `make` targets? | **A new target in `Package.swift`: `oscal-emit` produces an executable in `.build/release/`.** Lives in this repo because the AuditRecord schema is here. _[NEEDS CONFIRMATION — alternative is a single Swift script invoked by `swift run`; less ceremony but harder for compliance tooling to find.]_ |
| Q3 | Do we emit OSCAL Findings as well as Observations? | **Observations only for v1.** Findings are assessor-authored — they're the assessor's interpretation of observations against an assessment plan. The system owner emits the raw observations; the assessor synthesizes findings. Re-evaluate if downstream consumers explicitly request findings. |
| Q4 | What is the OSCAL POA&M version target? | **1.1.2 (matches STORY-022's component-definition target).** OSCAL 2.0 RC is not yet a final standard at the time of authoring; use the GA version both artifacts can share. _[NEEDS CONFIRMATION when 2.0 GA ships.]_ |
| Q5 | How are POA&M items uniquely identified across PRs? | **UUIDs assigned at creation, stored in a `poam-id-allocations.md` file in `oscal/`.** Matches the pattern STORY-022 uses for control statement UUIDs. Prevents two PRs from racing to use the same item ID. |
| Q6 | What happens when an AuditRecord references a tool that is later removed? | **Observation is retained for the duration of the retention window with a `historical` flag in remarks.** Compliance evidence is fundamentally historical — removing prior observations would be evidence tampering. The flag tells downstream tools the tool is no longer in the current Component Definition. |
| Q7 | Is the AR document tamper-protected separately from STORY-024's audit log? | **Reuses STORY-024's hash chain.** The AR is generated from the AuditRecord stream, so the hash chain over the source records transitively protects the AR contents. The AR itself does not need a separate chain. STORY-024's tamper detection therefore protects the AR provenance. |

---

## 5. TDD Implementation Map

| BDD Scenario | Step | Step Type | Unit Under Test | TDD Test Cases Required |
|---|---|---|---|---|
| POA&M validates | Given file committed | Given | YAML/JSON parse + OSCAL CLI shellout | test_poam_filePresent, test_poam_oscalCliValidates |
| Each §4 risk has POA&M item | Given §4 statements | Given | SecurityMdSection4Parser + PoamCoverageChecker | test_section4Parser_extractsAcceptedRiskStatements, test_poamCoverage_reportsMissingItems, test_poamCoverage_reportsExtraItems |
| Closed risks flip status | Given STORY-024 shipped | Given | RiskClosureSyncer | test_riskClosure_marksClosedWhenStoryReferenced, test_riskClosure_retainsClosureEvidence |
| AR validates | Given AR committed | Given | OSCAL CLI shellout | test_assessmentResults_filePresent, test_assessmentResults_oscalCliValidates |
| Mapping doc covers types | Given AuditRecord schema | Given | AuditRecord → Observation type-map | test_eventTypeMap_coversAllAuditRecordEventTypes, test_eventTypeMap_eachEntryHasNonEmptyControls |
| Continuous-monitoring conversion | When fixture run | When | OscalObservationEmitter | test_emitter_producesOneObservationPerRecord, test_emitter_populatesSubjects, test_emitter_populatesTimestamps, test_emitter_linksControls |
| Hash-chain break → AR | Given chain break in stream | Given | ChainBreakObservationBuilder | test_chainBreak_producesElevatedSeverityObservation, test_chainBreak_autoOpensPoamItem, test_chainBreak_includesOffsetInRemarks |
| Continuous append | When new events arrive | When | OscalAppender | test_appender_preservesPriorObservations, test_appender_updatesLastModified, test_appender_assignsNewUuidsWithoutCollision |
| Drift detector — new §4 | Given new accepted risk in PR | Given | OscalDriftDetector (STORY-022, extended) | test_drift_failsWhenSection4AddedWithoutPoam, test_drift_reportsLineNumberOfNewStatement |
| Drift detector — closed §4 | Given accepted risk removed | Given | OscalDriftDetector (extended) | test_drift_failsWhenSection4RemovedWithoutPoamFlip, test_drift_listsItemsNeedingStatusUpdates |
| README discoverability | When README read | When | Markdown link presence check | test_readme_linksAllThreeOscalArtifacts, test_readme_namesOscalModelVersions |
| AR mapping outline | Each event type → method, controls | Then | EventTypeMethodMapper | test_mapper_eachEventTypeHasMethod, test_mapper_appleScriptExecutedMapsToExamine, test_mapper_chainBreakMapsToTest |

---

## 6. Implementation Artifacts

### 6.1 Directory layout

```
oscal/
├── component-definition.json           (STORY-022)
├── plan-of-action-and-milestones.json  (this story)
├── assessment-results.json             (this story, regenerated/appended)
├── poam-id-allocations.md              (this story; UUID registry)
└── assessment-results-mapping.md       (this story; AuditRecord → OSCAL Observation table)
```

### 6.2 `oscal/plan-of-action-and-milestones.json` (skeleton)

```json
{
  "plan-of-action-and-milestones": {
    "uuid": "00000000-0000-0000-0000-0000000000aa",
    "metadata": {
      "title": "MCP-MacOSControl Plan of Action and Milestones",
      "last-modified": "2026-05-20T00:00:00Z",
      "version": "1.0.0",
      "oscal-version": "1.1.2",
      "roles": [
        { "id": "security-owner", "title": "Security Owner" }
      ],
      "responsible-parties": [
        { "role-id": "security-owner", "party-uuids": ["..."] }
      ]
    },
    "import-ssp": { "href": "../oscal/component-definition.json" },
    "system-id": { "id": "mcp-macos-control", "identifier-type": "https://ietf.org/rfc/rfc4122" },
    "poam-items": [
      {
        "uuid": "11111111-1111-1111-1111-111111111111",
        "title": "AppleScript security filter regex bypass class (SECURITY.md §4.1)",
        "description": "Accepted risk: the AppleScript denylist filter is regex-based and has documented bypass classes (escaping, comment injection, indirect identifier reference). Risk is accepted on the basis of the AuditRecorder compensating control. Re-evaluated when STORY-025 (fuzz harness) ships measurable coverage.",
        "related-controls": [{ "control-id": "si-10" }, { "control-id": "cm-7" }],
        "remarks": "status: risk-accepted. Owner: security-owner. Re-evaluation criteria: STORY-025 measurable bypass-class coverage achieves ≥80% reduction.",
        "related-observations": []
      },
      {
        "uuid": "22222222-2222-2222-2222-222222222222",
        "title": "Deferred production audit sink (SECURITY.md §4.4)",
        "description": "Accepted risk: in-memory AuditRecorder is not suitable for production. Closed by STORY-024.",
        "related-controls": [{ "control-id": "au-9" }],
        "remarks": "status: closed. Closed-by: STORY-024 implementation in commit <sha>. Closure-evidence: docs/stories/STORY-024-audit-log-integrity.md §8 Definition of Done.",
        "related-observations": []
      }
    ]
  }
}
```

### 6.3 `oscal/assessment-results.json` (skeleton)

```json
{
  "assessment-results": {
    "uuid": "00000000-0000-0000-0000-0000000000ab",
    "metadata": {
      "title": "MCP-MacOSControl Continuous Monitoring Assessment Results",
      "last-modified": "2026-05-20T00:00:00Z",
      "version": "1.0.0",
      "oscal-version": "1.1.2"
    },
    "import-ap": { "href": "tbd-by-assessor.json", "remarks": "Assessor-authored AP; system owner emits Observations only." },
    "local-definitions": { "activities": [] },
    "results": [
      {
        "uuid": "00000000-0000-0000-0000-0000000000ac",
        "title": "Continuous monitoring observations from AuditRecord stream",
        "description": "Observations generated from STORY-024 AuditRecord events. Each AuditRecord becomes one Observation.",
        "start": "2026-05-20T00:00:00Z",
        "observations": [
          {
            "uuid": "...",
            "title": "applescript_executed",
            "description": "AppleScript executed against TextEdit",
            "methods": ["EXAMINE"],
            "types": ["control-objective"],
            "subjects": [
              { "subject-uuid": "...", "type": "tool", "title": "run_applescript" },
              { "subject-uuid": "...", "type": "component", "title": "TextEdit" }
            ],
            "relevant-evidence": [
              { "href": "audit-records://2026-05-20T12:34:56Z/recordId-1234" }
            ],
            "collected": "2026-05-20T12:34:56Z",
            "remarks": "Mapped from AuditRecord by oscal-emit v1.0.0."
          }
        ]
      }
    ]
  }
}
```

### 6.4 `oscal/assessment-results-mapping.md` (skeleton)

```markdown
# AuditRecord → OSCAL Observation Mapping

| AuditRecord event type            | OSCAL Observation `methods` | Related controls | Subject types populated      |
|-----------------------------------|-----------------------------|-------------------|-------------------------------|
| applescript_executed              | EXAMINE                     | AU-2, AU-3, CM-7  | tool, component (target app)  |
| applescript_rejected              | EXAMINE                     | SI-10, CM-7       | tool, component               |
| click_menu_item_invoked           | EXAMINE                     | AU-2, AU-3        | tool, component, menu-path    |
| run_applescript_audit_chain_break | TEST                        | AU-9              | tool, chain-offset            |
| rate_limit_exceeded               | EXAMINE                     | AC-4              | tool-family, requester        |
| response_size_truncated           | EXAMINE                     | AC-4              | tool, requested-size, cap     |

## Field-level mapping

| AuditRecord field    | OSCAL Observation field          |
|----------------------|----------------------------------|
| `timestamp`          | `collected`                      |
| `toolName`           | `subjects[type=tool].title`      |
| `targetApp`          | `subjects[type=component].title` |
| `outcome` (success)  | `methods: [EXAMINE]`             |
| `outcome` (failure)  | `methods: [EXAMINE]`, `risks` populated |
| `recordId`           | `relevant-evidence[0].href` (audit-records://...) |
```

### 6.5 `Sources/OscalEmit/main.swift` (CLI skeleton)

```swift
// FILE: Sources/OscalEmit/main.swift
// STORY: STORY-037 — OSCAL Assessment Results & POA&M Artifacts
// COMPONENT: oscal-emit CLI

import Foundation
import MacOSControlLib    // for AuditRecord + AuditRecordStream from STORY-024

struct OscalEmit {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count >= 3 else {
            FileHandle.standardError.write("Usage: oscal-emit <audit-records.jsonl> <out/assessment-results.json>\n".data(using: .utf8)!)
            exit(2)
        }
        let stream = try AuditRecordStream(jsonLinesURL: URL(fileURLWithPath: args[1]))
        let emitter = OscalObservationEmitter(mapping: try EventTypeMapping.load())
        let existing = try AssessmentResultsDocument.loadOrCreate(at: URL(fileURLWithPath: args[2]))
        let appended = emitter.append(observationsFrom: stream, into: existing)
        try appended.write(to: URL(fileURLWithPath: args[2]))
    }
}

try OscalEmit.main()
```

### 6.6 Unit test scaffold (`Tests/MCP-MacOSControlTests/Oscal/`)

```swift
// FILE: Tests/MCP-MacOSControlTests/Oscal/OscalObservationEmitterTests.swift
// STORY: STORY-037 — OSCAL Assessment Results & POA&M Artifacts
// COMPONENT: OscalObservationEmitter

import XCTest
@testable import MacOSControlLib

final class OscalObservationEmitterTests: XCTestCase {

    func test_emitter_producesOneObservationPerRecord() throws {
        let records = [
            AuditRecord.fixture(eventType: "applescript_executed"),
            AuditRecord.fixture(eventType: "applescript_rejected")
        ]
        let emitter = OscalObservationEmitter(mapping: EventTypeMapping.default)
        let result = emitter.observations(from: records)
        XCTAssertEqual(result.count, 2)
    }

    func test_emitter_populatesCollectedTimestamp() throws {
        let ts = Date(timeIntervalSince1970: 1747000000)
        let record = AuditRecord.fixture(eventType: "applescript_executed", timestamp: ts)
        let obs = OscalObservationEmitter(mapping: .default).observations(from: [record]).first
        XCTAssertEqual(obs?.collected, ts)
    }

    func test_emitter_linksRelevantControls() throws {
        let record = AuditRecord.fixture(eventType: "applescript_executed")
        let obs = OscalObservationEmitter(mapping: .default).observations(from: [record]).first
        let controlIds = obs?.relatedControls.map { $0.controlId } ?? []
        XCTAssertEqual(Set(controlIds), Set(["au-2", "au-3", "cm-7"]))
    }

    func test_chainBreak_producesElevatedSeverity() throws {
        let record = AuditRecord.fixture(eventType: "run_applescript_audit_chain_break")
        let obs = OscalObservationEmitter(mapping: .default).observations(from: [record]).first
        XCTAssertFalse(obs?.risks.isEmpty ?? true,
                       "Chain-break observations must populate the risks field")
    }

    func test_emitter_appendsRatherThanRewrites() throws {
        // Round-trip: load existing AR, append observation, reload, original UUIDs unchanged.
        let url = URL(fileURLWithPath: NSTemporaryDirectory() + "ar-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let originalDoc = AssessmentResultsDocument.empty
        try originalDoc.write(to: url)
        let preCount = originalDoc.observations.count
        let appended = OscalObservationEmitter(mapping: .default)
            .append(observationsFrom: [AuditRecord.fixture(eventType: "applescript_executed")],
                    into: originalDoc)
        try appended.write(to: url)
        let reloaded = try AssessmentResultsDocument.load(from: url)
        XCTAssertEqual(reloaded.observations.count, preCount + 1)
    }
}
```

```swift
// FILE: Tests/MCP-MacOSControlTests/Oscal/PoamCoverageCheckerTests.swift
// STORY: STORY-037
// COMPONENT: PoamCoverageChecker

import XCTest
@testable import MacOSControlLib

final class PoamCoverageCheckerTests: XCTestCase {

    func test_coverage_passesWhenEverySection4StatementHasPoamItem() throws {
        let security = """
        ## 4.1 Accepted: regex bypass classes
        ## 4.4 Accepted: deferred production audit sink
        """
        let poam = PoamDocument.fixture(items: [
            .init(uuid: .init(), reference: "section-4.1"),
            .init(uuid: .init(), reference: "section-4.4")
        ])
        let report = PoamCoverageChecker.report(securityMd: security, poam: poam)
        XCTAssertTrue(report.missing.isEmpty)
    }

    func test_coverage_failsAndReportsMissingItem() throws {
        let security = """
        ## 4.1 Accepted: regex bypass classes
        ## 4.5 Accepted: a new risk added today
        """
        let poam = PoamDocument.fixture(items: [
            .init(uuid: .init(), reference: "section-4.1")
        ])
        let report = PoamCoverageChecker.report(securityMd: security, poam: poam)
        XCTAssertEqual(report.missing, ["section-4.5"])
    }
}
```

### 6.7 CI workflow integration

```yaml
# Add to ci.yml's main job, after STORY-021 SBOM and STORY-022 OSCAL validation:

- name: Validate OSCAL POA&M
  run: |
    npx -y @usnistgov/oscal-cli@latest validate oscal/plan-of-action-and-milestones.json --strict

- name: Validate OSCAL Assessment Results
  run: |
    npx -y @usnistgov/oscal-cli@latest validate oscal/assessment-results.json --strict

- name: OSCAL drift check — SECURITY.md §4 ↔ POA&M
  run: swift run oscal-drift check --section4 docs/SECURITY.md --poam oscal/plan-of-action-and-milestones.json

# In ci-integration.yml's nightly job, after the integration suite completes:

- name: Emit OSCAL observations from nightly audit-record stream
  run: |
    swift run oscal-emit "${RUNNER_TEMP}/audit-records.jsonl" oscal/assessment-results.json
    git diff --quiet oscal/assessment-results.json || (
      git config user.name "github-actions[bot]"
      git config user.email "github-actions[bot]@users.noreply.github.com"
      git add oscal/assessment-results.json
      git commit -m "chore(oscal): nightly observations append"
      git push
    )
```

---

## 7. Dependencies & Test Doubles

| Dependency | Type | Notes |
|---|---|---|
| STORY-022 component-definition.json | Internal | Source of control identifiers (au-2, au-3, si-10, cm-7, ac-4, au-9) |
| STORY-024 AuditRecord schema | Internal | Input to oscal-emit |
| `@usnistgov/oscal-cli` v2.0+ | OSS (npm) | Validates POA&M and AR JSON against the OSCAL schemas |
| `oscal-emit` CLI | New, this story | Local Swift package target |
| `oscal-drift` CLI | Extended from STORY-022 | Adds POA&M-coverage checking |
| Fixture AuditRecord JSONL | Test data | `Tests/.../Fixtures/audit-records-sample.jsonl` |

---

## 8. Definition of Done

**POA&M artifact**
- [ ] `oscal/plan-of-action-and-milestones.json` committed, validates with `oscal-cli --strict`
- [ ] Every SECURITY.md §4 accepted-risk statement has a corresponding poam-item
- [ ] Items closed by Sprint 6 hardening (e.g., §4.4 by STORY-024) marked `closed` with closure evidence
- [ ] `oscal/poam-id-allocations.md` records UUID assignments for stable cross-PR identifiers

**Assessment Results artifact**
- [ ] `oscal/assessment-results.json` committed, validates with `oscal-cli --strict`
- [ ] `oscal/assessment-results-mapping.md` documents the AuditRecord → Observation type map
- [ ] `oscal-emit` Swift target builds and emits an AR from a fixture AuditRecord stream
- [ ] Continuous append semantics: new observations appended, prior observations not modified
- [ ] Chain-break events (from STORY-024) generate elevated-severity observations and auto-open POA&M items

**Drift detection**
- [ ] `oscal-drift` extended to check SECURITY.md §4 ↔ POA&M coverage bidirectionally
- [ ] CI workflow fails on any drift between §4 and POA&M, in either direction
- [ ] Nightly job appends new observations from the integration-suite audit-record stream

**Tests**
- [ ] `OscalObservationEmitterTests` covers happy path, control linkage, chain-break elevation, append semantics
- [ ] `PoamCoverageCheckerTests` covers full coverage, missing-item, extra-item, closed-item cases
- [ ] Fixture AuditRecord JSONL committed with at least one example of each documented event type

**Documentation**
- [ ] `docs/SECURITY.md` §7.3 updated: roadmap items 2 and 3 marked as completed by this story
- [ ] `README.md` "Compliance Artifacts" section links to all three OSCAL artifacts and names their OSCAL model versions
- [ ] `docs/stories/STORY-037-oscal-assessment-results-and-poam.md` (this file) committed

---

## 9. Notes & Observations

- **Why split this from STORY-022?** STORY-022 was already at 3 points and focused on the Component Definition — the artifact that names what the system implements. POA&M and Assessment Results answer different questions ("what risks have we accepted" and "what evidence have we collected"). Different schemas, different inputs (POA&M reads SECURITY.md; AR reads the audit-record stream), different CI seams. Keeping them in one story would have created an 8-point monolith. Splitting them keeps STORY-022 a fast first artifact and lets this story take its time on the harder source-of-truth integration.
- **Why "Observations only, not Findings"?** The OSCAL hierarchy is: Observation (raw evidence) → Finding (assessor judgment about whether an Observation indicates a control failure) → POA&M item (remediation plan for a Finding). Findings are *assessor-authored* — the system owner shouldn't be making judgments about its own control failures. The system owner emits raw observations and accepted-risk-derived POA&M items; the assessor synthesizes findings from those observations against an assessment plan. Inverting this would be self-assessment, which is exactly what OSCAL's role separation prevents.
- **Why nightly rather than per-PR append?** Per-PR would conflict on `assessment-results.json` for parallel PRs, and would tightly couple the integration suite to the PR critical path. Nightly append (after the nightly integration run) is the cadence STORY-024's audit stream emits at anyway. If real-time AR emission becomes valuable, a Sprint 8 enhancement can move to a "stream-and-stitch" model.
- **Why a Swift target rather than a Python script?** The AuditRecord schema is canonical in Swift (STORY-024). Re-implementing the schema in Python doubles the maintenance surface. The OSCAL JSON output is the same regardless of the producer language; downstream OSCAL tooling doesn't care.
- **Relationship to STORY-022.** This story extends STORY-022's `oscal-drift` CLI for POA&M coverage. The shared CLI keeps drift-detection consistent across all three OSCAL artifacts.
- **Relationship to STORY-024.** STORY-024's hash chain transitively protects this story's AR — because the AR is derived from the chain-protected AuditRecord stream, tampering with an AR observation requires breaking the source chain, which STORY-024 detects.
- **Relationship to STORY-025 (fuzz harness, Sprint 7).** The POA&M item for §4.1 (regex bypass) names STORY-025 as a closure milestone. When STORY-025 ships, its DoD should include updating this POA&M item with the measured bypass-class coverage.
- **Persona alignment.** The system-prompt persona for this project ("You build OSCAL into your projects to help automate security compliance and visibility") commits to OSCAL adoption. STORY-022 alone partially satisfies this; the full three-artifact OSCAL surface is what makes the commitment operationally true.
