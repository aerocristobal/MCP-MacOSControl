# STORY-021 — Software Supply Chain Security: SBOM, SCA, Dependency Review

**Epic:** EPIC-7 · Production Hardening (new epic introduced at Round 8)
**Priority:** 🔴 Critical
**Story Points:** 3
**Sprint Target:** Sprint 6 (Hardening)
**Dependencies:** None
**Refinement Round:** 8 — Newly added during the Round 8 close-out audit. Closes the NIST SP 800-218 (SSDF) supply-chain control gap identified across all six prior epics.

---

## 1. User Story Narrative

```
Story: Software Supply Chain Security
In order to deploy MCP-MacOSControl into regulated environments and meet NIST SSDF supply-chain controls (PS.3, PW.4, PW.8)
As a security reviewer or compliance officer evaluating the project for production use
I want every PR to produce a CycloneDX SBOM, run Software Composition Analysis against known vulnerabilities, and gate on critical findings
So that supply-chain attacks (typosquatted Swift packages, transitively pulled CVEs, license violations) are detected before merge rather than discovered post-release
```

**Additional Context:** The project has documented its NIST SP 800-53 control mappings (AU-2, AU-3, SI-10, AC-3, AC-4, CM-7) in `docs/SECURITY.md` §7 but does not yet address the SR (Supply Chain Risk Management) control family. The current CI runs `swift build` and `swift test` without any dependency review, SBOM generation, or vulnerability scanning. With Package.swift pulling at least the MCP Swift SDK + transitive dependencies, the project's actual supply-chain footprint is undocumented. This story establishes the SCA + SBOM foundation; STORY-022 (OSCAL) consumes the SBOM as a component evidence artifact; STORY-026 (secret scanning, follow-up) complements this with credential hygiene.

---

## 2. Acceptance Criteria (BDD Scenarios)

```gherkin
@epic-7 @story-021 @security @supply-chain
Feature: Software Supply Chain Security
  In order to detect supply-chain risks before merge
  As a security reviewer
  I want every PR to generate an SBOM and run SCA with policy gates

  Background:
    Given the GitHub Actions CI pipeline is configured
    And the repository ships a Package.swift with declared dependencies

  Scenario: Every PR build produces a CycloneDX SBOM artifact
    Given a pull request is opened that modifies any file
    When the CI workflow completes the build step
    Then a CycloneDX 1.5+ SBOM is generated covering all transitive dependencies
    And the SBOM is uploaded as a workflow artifact named "sbom-cyclonedx.json"
    And the SBOM identifies the MCP Swift SDK and every transitive Swift package by name + version + SHA

  Scenario: SCA scans the SBOM for known vulnerabilities on every PR
    Given a PR is opened and the SBOM has been generated
    When the SCA tool runs against the SBOM
    Then a vulnerability report is uploaded as a workflow artifact
    And the report names CVEs by ID, CVSS score, and affected component
    And the PR check status reflects the result (success when no critical findings; failure otherwise)

  Scenario: PR is blocked on critical-severity vulnerability findings
    Given a dependency pinned in Package.resolved has a known CVE with CVSS ≥ 9.0
    When the SCA scan runs in PR CI
    Then the workflow step fails with a non-zero exit code
    And the PR check is marked failed
    And the failure message names the offending dependency, the CVE ID, and the CVSS score

  Scenario: High-severity findings produce a warning but do not block merge
    Given a dependency has a known CVE with CVSS between 7.0 and 8.9
    When the SCA scan runs
    Then the workflow logs a warning containing the CVE details
    And the PR check status remains success
    And a comment is posted to the PR summarizing high-severity findings

  Scenario: License-policy violation is flagged
    Given a transitive dependency has a license outside the project's allowed list (MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC)
    When the SBOM generator runs
    Then the workflow step fails with an "unallowed_license" message
    And the failure names the offending dependency and the disallowed license

  Scenario: Dependabot maintains pinned versions
    Given the Dependabot configuration is committed at .github/dependabot.yml
    When a dependency has a newer compatible version published
    Then Dependabot opens a PR proposing the upgrade
    And the PR triggers a full CI run including the new SCA scan

  Scenario: SBOM is published as a release artifact on tagged releases
    Given a release is tagged on the main branch
    When the release workflow runs
    Then the CycloneDX SBOM is attached to the GitHub Release
    And a CycloneDX VEX (Vulnerability Exploitability eXchange) document is also attached when applicable

  Scenario Outline: Severity policy is consistent across tools
    Given an SCA finding at severity <severity>
    When the CI workflow evaluates the finding
    Then the gate behavior is <gate>

    Examples:
      | severity   | gate                              |
      | critical   | block PR — workflow fails         |
      | high       | warn — PR comment, no block       |
      | medium     | log only — visible in artifact    |
      | low        | log only — visible in artifact    |
```

---

## 3. Scenario Coverage Checklist

| Coverage Type | Scenario(s) | Status |
|---|---|---|
| Main success path | SBOM generated; SCA runs on every PR | ✅ |
| Alternative success path | High-severity warning; Dependabot upgrade flow; release-time publication | ✅ |
| Boundary condition | Severity policy outline; CVSS thresholds at 7.0 and 9.0 | ✅ |
| Error / rejection path | Critical CVE blocks PR; license violation blocks PR | ✅ |
| Business rule edge case | VEX document at release time for known-but-not-exploitable findings | ✅ |

---

## 4. Three Amigos Open Questions

| # | Question | Resolution |
|---|---|---|
| Q1 | Which SBOM format — CycloneDX or SPDX? | **CycloneDX 1.5+.** Better Swift Package Manager tool support via `cyclonedx-swift`; native VEX integration; FedRAMP guidance accepts both. _[NEEDS CONFIRMATION]_ |
| Q2 | Which SCA tool — Grype, Trivy, Snyk, GitHub Dependabot? | **Combination: GitHub Dependency Review action (free, native, PR-gated) + Grype as the SBOM-based scanner.** Both are FOSS, no external API key required, run in parallel. Snyk's free tier is not viable for daily PR volume on a regulated project. _[NEEDS CONFIRMATION]_ |
| Q3 | Where is the allowed-license list defined? | **`.github/sbom-policy.yml`** committed to repo. Lists allowed SPDX identifiers + named exceptions. Editable via PR with security review. |
| Q4 | What is the CVSS threshold for blocking? | **9.0 (Critical only) blocks; 7.0+ warns.** Trades off some false positives (CVEs reachable only in code paths not used) against actually blocking PRs. Documented in `.github/sbom-policy.yml`. _[NEEDS CONFIRMATION]_ |
| Q5 | How are accepted/exploitable-but-mitigated CVEs documented? | **VEX document at `.github/vex-statements.json`** (CycloneDX VEX 0.5). Each accepted CVE has an `affected | not_affected | fixed | under_investigation` status, with justification text. Reviewed at sprint planning. |
| Q6 | Do we cache vulnerability databases? | **Yes — keyed by date. ** Daily refresh keeps the database current without re-downloading on every PR. CI cache `.grype-db` keyed by `YYYY-MM-DD`. |
| Q7 | Dependabot frequency? | **Weekly for npm-style hot dependencies (none currently); monthly for Swift packages.** Swift ecosystem moves more slowly; weekly cadence creates churn without payoff. _[NEEDS CONFIRMATION]_ |

---

## 5. TDD Implementation Map

| BDD Scenario | Step | Step Type | Unit Under Test | TDD Test Cases Required |
|---|---|---|---|---|
| SBOM generation | When build completes | When | `.github/workflows/ci.yml` SBOM step | (workflow-level — verified by CI green/red) |
| SCA scan runs | When SBOM is uploaded | When | `.github/workflows/ci.yml` SCA step | (workflow-level) |
| Critical CVE blocks PR | Given CVSS ≥ 9.0 | Given | Fixture SBOM with known-critical CVE | test_scaJob_failsWhenSbomContainsCriticalCve (a smoke shell test that runs Grype against a synthetic SBOM) |
| License violation | Given GPL transitive | Given | Synthetic Package.resolved with GPL dep | test_sbomJob_failsWhenLicensePolicyViolated |
| Dependabot config valid | Given dependabot.yml present | Given | YAML parser | test_dependabotConfig_parsesAndContainsExpectedEntries |
| Severity outline | Each severity → expected gate | Then | Severity-to-gate function | test_severityGate_returnsBlock_forCritical, test_severityGate_returnsWarn_forHigh, test_severityGate_returnsLog_forMediumAndLow |
| VEX document | When release tagged | When | Release workflow VEX assembly | test_releaseWorkflow_attachesVexWhenStatementsExist |

---

## 6. Implementation artifacts

### 6.1 `.github/workflows/ci.yml` additions

```yaml
# Add to existing build-and-test job, after "Run Tests" step:

- name: Generate CycloneDX SBOM
  uses: CycloneDX/gh-swift-sbom@v1   # or equivalent; see Q1
  with:
    output-format: json
    output-file: sbom-cyclonedx.json

- name: Upload SBOM artifact
  uses: actions/upload-artifact@v4
  with:
    name: sbom-cyclonedx
    path: sbom-cyclonedx.json

- name: Dependency Review (native)
  if: github.event_name == 'pull_request'
  uses: actions/dependency-review-action@v4
  with:
    fail-on-severity: critical
    allow-licenses: MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC

- name: SCA scan (Grype)
  uses: anchore/scan-action@v3
  with:
    sbom: sbom-cyclonedx.json
    severity-cutoff: critical
    fail-build: true
    output-format: sarif
    output-file: grype-results.sarif

- name: Upload SARIF to GitHub Security tab
  if: always()
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: grype-results.sarif
```

### 6.2 `.github/dependabot.yml`

```yaml
version: 2
updates:
  - package-ecosystem: "swift"
    directory: "/"
    schedule:
      interval: "monthly"
    open-pull-requests-limit: 5
    labels: ["dependencies", "security-review"]
    reviewers: ["aerocristobal"]   # adjust per project
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    labels: ["dependencies", "ci"]
```

### 6.3 `.github/sbom-policy.yml`

```yaml
version: 1
allowed_licenses:
  - MIT
  - Apache-2.0
  - BSD-2-Clause
  - BSD-3-Clause
  - ISC
severity_gates:
  block: critical              # CVSS >= 9.0
  warn:  high                  # 7.0 - 8.9
  log:   [medium, low]
vex_statements_file: .github/vex-statements.json
```

### 6.4 Test fixture for synthetic SBOM (TDD scaffold)

```swift
// FILE: Tests/MCP-MacOSControlTests/SupplyChain/SbomPolicyTests.swift
// STORY: STORY-021 — Software Supply Chain Security
// COMPONENT: .github/sbom-policy.yml validation

import XCTest

final class SbomPolicyTests: XCTestCase {

    func test_sbomPolicy_isParseable() throws {
        let policyURL = URL(fileURLWithPath: ".github/sbom-policy.yml")
        let data = try Data(contentsOf: policyURL)
        XCTAssertGreaterThan(data.count, 0)
        // YAML parse round-trip would validate structure — full check via CI step
    }

    func test_sbomPolicy_listsExpectedAllowedLicenses() throws {
        let content = try String(contentsOfFile: ".github/sbom-policy.yml")
        for required in ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC"] {
            XCTAssertTrue(content.contains(required), "Missing \(required) in allowed licenses")
        }
    }

    func test_dependabotConfig_isPresentAndValid() throws {
        let url = URL(fileURLWithPath: ".github/dependabot.yml")
        let data = try Data(contentsOf: url)
        let str = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(str.contains("package-ecosystem: \"swift\""))
        XCTAssertTrue(str.contains("package-ecosystem: \"github-actions\""))
    }
}
```

---

## 7. Dependencies & Test Doubles

| Dependency | Type | Notes |
|---|---|---|
| GitHub Actions | External | Required CI substrate |
| `actions/dependency-review-action@v4` | GitHub-native | First-line gate on PRs |
| `anchore/scan-action@v3` (Grype) | OSS | SARIF output to GitHub Security tab |
| `CycloneDX/gh-swift-sbom@v1` or equivalent | OSS | SBOM generator for Swift Package Manager |
| GitHub Security advisories DB | External | Refreshed daily via Grype DB cache |

---

## 8. Definition of Done

**SBOM**
- [ ] CycloneDX 1.5+ JSON SBOM generated on every push and PR
- [ ] SBOM identifies every transitive dependency by name, version, and SHA
- [ ] SBOM uploaded as workflow artifact `sbom-cyclonedx`

**SCA**
- [ ] GitHub Dependency Review action enabled, configured to `fail-on-severity: critical`
- [ ] Grype scan runs against the generated SBOM
- [ ] SARIF results uploaded to GitHub Security tab via codeql-action/upload-sarif
- [ ] Critical-severity findings block the PR; high-severity findings post a comment but pass

**Policy artifacts**
- [ ] `.github/sbom-policy.yml` committed and parseable
- [ ] `.github/dependabot.yml` committed and parseable
- [ ] `.github/vex-statements.json` committed (initial content may be empty array)
- [ ] Allowed-license list documented and matches policy file

**Tests**
- [ ] `SbomPolicyTests` passes — verifies policy artifacts are present and well-formed
- [ ] A synthetic SBOM fixture with a known critical CVE proves the SCA gate fires (manual verification on a feature branch is acceptable; documented in `docs/SECURITY.md`)

**Documentation**
- [ ] `docs/SECURITY.md` updated with a new §8 "Supply Chain Risk Management" mapping to NIST SP 800-53 SR-3, SR-4, SR-11
- [ ] `docs/stories/STORY-021-software-supply-chain-security.md` (this file) committed
- [ ] `README.md` updated: "Security" section references supply-chain practices
- [ ] STORY-022's OSCAL component definition references the SBOM artifact

---

## 9. Notes & Observations

- **Why CycloneDX rather than SPDX?** Both are FedRAMP-acceptable. CycloneDX has better Swift Package Manager tooling, native VEX integration, and simpler JSON shape. SPDX is the more common SBOM format in some federal procurement guidance; if the project's downstream consumers require SPDX, generation of both formats is a 1-line tool config change.
- **Why 9.0 (Critical) as the block threshold rather than 7.0?** A blanket block at "high" severity blocks PRs on findings that are typically reachable-but-mitigated or not reachable from this codebase. The intermediate "warn but don't block" tier gives operators visibility while letting feature work continue. Reassess after 30 days of operation.
- **Why not Snyk / Mend / commercial scanners?** Free-tier rate limits don't survive sustained PR volume; commercial seats add procurement friction. Grype + GitHub Dependency Review give 90%+ of the value with zero cost and no external service dependency.
- **VEX statements are reviewed at sprint planning.** Adding a VEX statement is a security-review action — it asserts that a known CVE is not exploitable in this codebase, which requires evidence. Treating VEX as a regular PR (with security-review label) keeps the documentation honest.
- **Relationship to STORY-022 (OSCAL):** The SBOM produced here is an evidence artifact referenced in the OSCAL component definition. The two stories share an evidence-management pattern.
- **Relationship to STORY-024 (Audit log integrity):** The SBOM is itself an attested audit input. Sprint 7's signing/notarization story (STORY-023) closes the loop by signing the SBOM.
