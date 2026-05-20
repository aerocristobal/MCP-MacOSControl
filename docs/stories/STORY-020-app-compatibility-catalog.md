# STORY-020 — App Compatibility Catalog & Living Document

**Epic:** EPIC-6 · Agent Interaction Hierarchy
**Priority:** 🟢 Medium
**Story Points:** 2
**Sprint Target:** Sprint 5 (parallel with STORY-012)
**Dependencies:** 🔒 STORY-010 (smart_interact), 🔒 STORY-012 (Integration suite — produces observation data), 🔒 STORY-019 (Registry — provides expectation data)
**Refinement Round:** 7 — Newly added during Epic 6 refinement. Carves the "regression suite documents expected interaction_method for each standard macOS app" line out of STORY-012's DoD into a tracked, maintained deliverable.

---

## 1. User Story Narrative

```
Story: App Compatibility Catalog & Living Document
In order to know which interaction layers actually work for which macOS applications and to keep that knowledge current as macOS evolves
As an operator, contributor, or downstream consumer of MCP-MacOSControl
I want a generated catalog document listing each tested application alongside its observed interaction methods, registry expectations, and macOS version compatibility
So that the project's compatibility claims are evidence-based rather than aspirational, and so the per-app registry stays calibrated to reality
```

**Additional Context:** Two prior stories produce raw data: STORY-019 declares *expected* per-app capabilities; STORY-012 records *observed* `interaction_method` values from real integration runs. Neither story currently has a place that publishes the merged truth as a human-readable document. Without one, the registry rots, integration scenarios drift from the registry, and downstream users have no way to predict whether their app will work. This story produces the publish step: a Markdown file under `docs/APP-COMPATIBILITY.md` regenerated from STORY-012 integration runs, diffed against STORY-019 expectations, with discrepancies surfaced as build warnings. The catalog grows organically — every new integration scenario adds a row; every registry update is verified or rejected against the catalog.

---

## 2. Acceptance Criteria (BDD Scenarios)

```gherkin
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
    And the generator returns a non-zero exit code if any discrepancy is found

  Scenario: Catalog is regenerated on every successful integration run
    Given the integration suite passes on a nightly CI run
    When the CI workflow completes
    Then "docs/APP-COMPATIBILITY.md" is regenerated
    And if the regenerated content differs from the committed version a PR is opened with the diff

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
    So that the registry update decision is grounded in evidence

  Scenario: Catalog handles applications removed from integration coverage gracefully
    Given the catalog previously listed "com.example.deprecatedapp"
    And no integration scenario currently exercises that app
    When the catalog generator runs
    Then the deprecatedapp row is marked "stale" with the date of last observation
    And after 6 months without re-verification the row is moved to an archived section
    But the row is not deleted (operators may still query historical observations)
```

---

## 3. Scenario Coverage Checklist

| Coverage Type | Scenario(s) | Status |
|---|---|---|
| Main success path | Catalog regenerated from observations | ✅ |
| Alternative success path | Discrepancy detection; per-version matrix; maintainer-facing data | ✅ |
| Boundary condition | Stale-row archival policy at 6 months | ✅ |
| Error / rejection path | Generator exits non-zero on discrepancies | ✅ |
| Business rule edge case | Removed-but-historically-observed apps marked stale, not deleted | ✅ |

---

## 4. Three Amigos Open Questions (Round 7)

| # | Question | Resolution |
|---|---|---|
| Q1 | Markdown or some richer format (HTML table, sortable JSON)? | **Markdown for the published doc, JSON as the canonical data source.** Markdown for humans browsing the repo on GitHub. JSON for tooling. Markdown is generated from JSON. _[NEEDS CONFIRMATION]_ |
| Q2 | Where is the observation JSON stored? | **`docs/compatibility-observations.json`, committed to the repo.** Living data, plain-text, diffable in PRs. Not in a database, not a CI artifact only — the historical record matters and must travel with the source. _[NEEDS CONFIRMATION]_ |
| Q3 | What about apps the team has never tested? Should the catalog include speculative entries? | **No.** The whole point is evidence-based. Speculative entries can live in the STORY-019 registry as `unknown`; once an integration run produces observations, they graduate into the catalog. |
| Q4 | What's the discrepancy threshold for failing the build? | **Any discrepancy is a build warning; persistent discrepancies (3 consecutive runs) are build failures.** Single-run discrepancies could be transient (app crashed mid-test); persistent ones are real and must be reconciled. _[NEEDS CONFIRMATION]_ |
| Q5 | How does an operator add a new app to the catalog? | **Add a new integration scenario in STORY-012; the catalog absorbs it automatically.** No catalog editing by hand — the catalog is a derived artifact. |
| Q6 | Does the catalog include performance observations (latency per layer)? | **No at v1.** Latency is interesting but adds a separate dimension to the schema. Could be a future iteration. Keep v1 focused on the boolean "does this layer work" question. |

---

## 5. TDD Implementation Map

| BDD Scenario | Step | Step Type | Unit Under Test | TDD Test Cases Required |
|---|---|---|---|---|
| Generator produces Markdown | When generator runs | When | `CompatibilityCatalogGenerator.generate(observations:registry:)` | test_generatesMarkdown_withRowPerObservedApp, test_includesAllRequiredColumns |
| Discrepancy flagging | Given expectation ≠ observed | Given | `DiscrepancyDetector.find(observations:registry:)` | test_detectsAxExpectedButApplescriptObserved, test_summarySectionListsAllDiscrepancies |
| Discrepancy non-zero exit | When persistent discrepancy | When | `CatalogGeneratorCLI.run(args:)` | test_exitCode_isNonZero_whenDiscrepancyPresent, test_exitCode_isZero_whenAllAligned |
| Regenerated on CI | When CI run completes | When | `.github/workflows/ci-integration.yml` job | (verified by workflow itself; not a Swift unit test) |
| Version matrix | Given multi-version runs | Given | `CompatibilityCatalogGenerator.buildVersionMatrix(observations:)` | test_matrixIncludesEveryObservedMacOSVersion, test_untestedVersionsMarkedAsUntested |
| Maintainer-facing data | Then operator can consult | Then | `CompatibilityCatalogGenerator.appSection(_:)` | test_appSectionIncludesLastObservedDate_andMacOSVersion |
| Stale-row handling | When app no longer exercised | When | `CompatibilityCatalogGenerator.markStaleRows(observations:cutoff:)` | test_marksStaleAfterNoRecentObservation, test_movesToArchivedAfter6MonthsCutoff, test_doesNotDeleteHistoricalRows |

---

## 6. TDD Unit Test Scaffolds

### 6.1 `CompatibilityCatalogGenerator`

```swift
// FILE: Tests/MCP-MacOSControlTests/Catalog/CompatibilityCatalogGeneratorTests.swift
// STORY: STORY-020 — App Compatibility Catalog
// COMPONENT: CompatibilityCatalogGenerator

import XCTest
@testable import MacOSControlLib

final class CompatibilityCatalogGeneratorTests: XCTestCase {

    var generator: CompatibilityCatalogGenerator!
    var fakeClock: FakeClock!

    override func setUp() {
        super.setUp()
        fakeClock = FakeClock(now: Date(timeIntervalSince1970: 1_716_000_000)) // 2024-05-18
        generator = CompatibilityCatalogGenerator(clock: fakeClock)
    }

    // MARK: - Markdown generation

    func test_generate_producesMarkdownTableWithExpectedColumns() throws {
        let observations = [
            Observation(bundleId: "com.apple.TextEdit",
                        interactionMethod: "ax_semantic",
                        macOSVersion: "14.5",
                        timestamp: fakeClock.now)
        ]
        let registry = FakeAppCapabilityRegistry()
        registry.stubCapability(forBundle: "com.apple.TextEdit",
                                axSupported: true, applescriptSupported: true)
        let markdown = try generator.generate(observations: observations, registry: registry)
        XCTAssertTrue(markdown.contains("| bundle_identifier"))
        XCTAssertTrue(markdown.contains("| observed_interaction_methods"))
        XCTAssertTrue(markdown.contains("| registry_expectation"))
        XCTAssertTrue(markdown.contains("| macOS_version_tested"))
        XCTAssertTrue(markdown.contains("| last_verified_date"))
        XCTAssertTrue(markdown.contains("com.apple.TextEdit"))
    }

    // MARK: - Discrepancy detection

    func test_detectsDiscrepancy_whenRegistryExpectsAxButObservedIsAppleScript() throws {
        let observations = [
            Observation(bundleId: "com.example.legacyapp",
                        interactionMethod: "applescript",
                        macOSVersion: "14.5",
                        timestamp: fakeClock.now)
        ]
        let registry = FakeAppCapabilityRegistry()
        registry.stubCapability(forBundle: "com.example.legacyapp",
                                axSupported: true, applescriptSupported: true)
        let result = try generator.generateWithDiscrepancyAnalysis(
            observations: observations, registry: registry)
        XCTAssertTrue(result.markdown.contains("⚠️ discrepancy"))
        XCTAssertEqual(result.discrepancies.count, 1)
        XCTAssertEqual(result.discrepancies[0].bundleId, "com.example.legacyapp")
    }

    func test_noDiscrepancy_whenObservedMatchesRegistry() throws {
        let observations = [
            Observation(bundleId: "com.apple.TextEdit",
                        interactionMethod: "ax_semantic",
                        macOSVersion: "14.5",
                        timestamp: fakeClock.now)
        ]
        let registry = FakeAppCapabilityRegistry()
        registry.stubCapability(forBundle: "com.apple.TextEdit",
                                axSupported: true, applescriptSupported: true)
        let result = try generator.generateWithDiscrepancyAnalysis(
            observations: observations, registry: registry)
        XCTAssertTrue(result.discrepancies.isEmpty)
    }

    // MARK: - Version matrix

    func test_buildVersionMatrix_includesEveryObservedMacOSVersion() throws {
        let observations = [
            Observation(bundleId: "com.apple.TextEdit", interactionMethod: "ax_semantic",
                        macOSVersion: "13.6", timestamp: fakeClock.now),
            Observation(bundleId: "com.apple.TextEdit", interactionMethod: "ax_semantic",
                        macOSVersion: "14.5", timestamp: fakeClock.now),
            Observation(bundleId: "com.apple.TextEdit", interactionMethod: "ax_semantic",
                        macOSVersion: "15.1", timestamp: fakeClock.now),
        ]
        let matrix = try generator.buildVersionMatrix(observations: observations)
        XCTAssertTrue(matrix.versions.contains("13.6"))
        XCTAssertTrue(matrix.versions.contains("14.5"))
        XCTAssertTrue(matrix.versions.contains("15.1"))
    }

    // MARK: - Stale-row policy

    func test_markStaleRows_marksRowsWithObservationsOlderThan90Days() throws {
        let veryOld = fakeClock.now.addingTimeInterval(-100 * 86_400)
        let recent = fakeClock.now.addingTimeInterval(-10 * 86_400)
        let observations = [
            Observation(bundleId: "old.app", interactionMethod: "ax_semantic",
                        macOSVersion: "14.5", timestamp: veryOld),
            Observation(bundleId: "new.app", interactionMethod: "ax_semantic",
                        macOSVersion: "14.5", timestamp: recent),
        ]
        let report = try generator.staleRowReport(observations: observations)
        XCTAssertTrue(report.staleBundleIds.contains("old.app"))
        XCTAssertFalse(report.staleBundleIds.contains("new.app"))
    }

    func test_archiveRows_movesToArchivedSectionAfter180Days() throws {
        let veryOld = fakeClock.now.addingTimeInterval(-200 * 86_400)
        let observations = [
            Observation(bundleId: "ancient.app", interactionMethod: "ax_semantic",
                        macOSVersion: "13.6", timestamp: veryOld),
        ]
        let markdown = try generator.generate(observations: observations,
                                              registry: FakeAppCapabilityRegistry())
        XCTAssertTrue(markdown.contains("## Archived"))
        XCTAssertTrue(markdown.contains("ancient.app"))
    }

    func test_archiveRows_doesNotDeleteHistoricalObservations() throws {
        let veryOld = fakeClock.now.addingTimeInterval(-1000 * 86_400)
        let observations = [
            Observation(bundleId: "ancient.app", interactionMethod: "ax_semantic",
                        macOSVersion: "12.0", timestamp: veryOld),
        ]
        let markdown = try generator.generate(observations: observations,
                                              registry: FakeAppCapabilityRegistry())
        XCTAssertTrue(markdown.contains("ancient.app"))
        XCTAssertTrue(markdown.contains("12.0"))
    }
}
```

### 6.2 `CatalogGeneratorCLI` (exit-code contract)

```swift
// FILE: Tests/MCP-MacOSControlTests/Catalog/CatalogGeneratorCLITests.swift
// STORY: STORY-020 — App Compatibility Catalog
// COMPONENT: CatalogGeneratorCLI

import XCTest
@testable import MacOSControlLib

final class CatalogGeneratorCLITests: XCTestCase {

    func test_exit_returnsZero_whenAllObservationsAlignWithRegistry() async throws {
        let exitCode = await CatalogGeneratorCLI.run(
            observationsPath: fixtureURL("aligned-observations.json"),
            registryPath: fixtureURL("default-app-capabilities.json"),
            outputPath: tempOutputPath())
        XCTAssertEqual(exitCode, 0)
    }

    func test_exit_returnsNonZero_whenPersistentDiscrepancyPresent() async throws {
        let exitCode = await CatalogGeneratorCLI.run(
            observationsPath: fixtureURL("discrepant-observations-3-consecutive.json"),
            registryPath: fixtureURL("default-app-capabilities.json"),
            outputPath: tempOutputPath())
        XCTAssertNotEqual(exitCode, 0)
    }

    func test_exit_returnsZero_whenSingleRunDiscrepancyOnly() async throws {
        // Single-run discrepancy → warning only, not failure
        let exitCode = await CatalogGeneratorCLI.run(
            observationsPath: fixtureURL("discrepant-observations-single-run.json"),
            registryPath: fixtureURL("default-app-capabilities.json"),
            outputPath: tempOutputPath())
        XCTAssertEqual(exitCode, 0)
    }
}
```

---

## 7. Dependencies & Test Doubles

| Dependency | Type | Source | Notes |
|---|---|---|---|
| `Observation` JSON format | **New** | Schema documented in `docs/compatibility-observations-schema.md` | Written by STORY-012's integration scenarios, read here |
| `AppCapabilityRegistry` (STORY-019) | Real | `FakeAppCapabilityRegistry` | Read-only consumer |
| `Clock` abstraction | Existing | `FakeClock` | Deterministic stale/archive cutoff tests |
| GitHub Actions workflow | Real | n/a — verified by manual workflow_dispatch and the next CI run | Auto-PR on catalog diff |
| Markdown rendering library | Standard string operations | No double | No dependency on external markdown library — simple table generation |

---

## 8. Definition of Done

**Generator**
- [ ] `Sources/MacOSControlLib/Catalog/CompatibilityCatalogGenerator.swift` produced
- [ ] CLI entrypoint `mcp-macos-control-catalog` built from a separate Swift Package target
- [ ] Generator consumes `docs/compatibility-observations.json` and STORY-019's registry, emits `docs/APP-COMPATIBILITY.md`
- [ ] Generator exits non-zero on persistent discrepancies (≥ 3 consecutive runs in the observations file)
- [ ] Generator exits zero on single-run discrepancies (warns in output only)

**Catalog content**
- [ ] Markdown table with columns: `bundle_identifier`, `localized_name`, `observed_interaction_methods`, `registry_expectation`, `macOS_version_tested`, `last_verified_date`, `notes`
- [ ] Summary section above the table: total apps, total discrepancies, last regeneration date
- [ ] Per-macOS-version matrix section
- [ ] Archived section for rows older than 180 days
- [ ] Footer linking to STORY-019 (registry source-of-truth) and STORY-012 (observation source)

**CI integration**
- [ ] Catalog regenerated automatically after every successful integration run
- [ ] If regenerated content differs from the committed `docs/APP-COMPATIBILITY.md`, a PR is opened by a bot with the diff
- [ ] Catalog generator runs in unit-test CI as well (smoke test, no observations needed)

**Observations data contract (with STORY-012)**
- [ ] STORY-012's integration scenarios write to `docs/compatibility-observations.json` on each successful run
- [ ] Observation schema: `{ bundle_identifier, interaction_method, macOS_version, timestamp, scenario_name }`
- [ ] STORY-012's test failure does NOT delete prior observations; new observations are appended
- [ ] Observations file kept under 1 MB by truncating individual app history to last 50 entries

**Tests**
- [ ] All BDD scenarios pass in CI (where applicable — CI-workflow scenarios verified manually)
- [ ] Unit coverage ≥ 85% on `CompatibilityCatalogGenerator`
- [ ] Unit coverage 100% on `CatalogGeneratorCLI` (small surface — easy)

**Documentation**
- [ ] `docs/stories/STORY-020-app-compatibility-catalog.md` (this file) committed
- [ ] `Tests/MCP-MacOSControlTests/Features/story-020-app-compatibility-catalog.feature` committed
- [ ] `docs/APP-COMPATIBILITY.md` exists as a generated artifact (initial content can be minimal)
- [ ] `docs/compatibility-observations-schema.md` documents the JSON schema

---

## 9. Notes & Observations

- **Why is the catalog a derived artifact, not hand-edited?** Hand-edited docs rot. Generated docs from CI observations stay current. The cost of "you can't edit it manually" is recovered many times over by "it actually reflects reality."
- **Why isn't this in Epic 4 (Tool Quality)?** Epic 4 covers MCP protocol primitives (annotations, errors, resources, prompts). The compatibility catalog is downstream of those primitives and specifically about the interaction-hierarchy decisions made in Epic 6. Placement in Epic 6 keeps related concerns together.
- **Why 6 months for archival, 90 days for stale?** Conservative. macOS major releases are roughly annual; an app untouched for 6 months has plausibly survived a macOS upgrade unattended. 90 days for stale-marking is one quarter — long enough to ignore transient gaps in nightly runs (holidays, etc.) but short enough to catch real drift. _[NEEDS CONFIRMATION]_
- **Why 50-entry history limit per app?** Practical — the observations file is committed to git, so size matters. 50 nightly runs is ~7 weeks of history per app, which is sufficient context for any human review.
- **Why does the generator exit non-zero on persistent discrepancies?** It's the only way to make CI surface registry drift. A passing nightly is meaningless if it silently produces a doc that contradicts the shipped registry. Hard failure forces resolution: either update the registry (STORY-019) or fix the underlying compatibility regression.
- **What about pull-request workflows for the registry?** When the catalog flags a persistent discrepancy, the operator's choices are: (a) update the registry to match observed reality, (b) investigate and fix the integration test, (c) investigate and fix the underlying tool bug. All three paths are PR workflows. The catalog generator's job is just to make the discrepancy impossible to ignore.
