# Security Policy and Threat Model

> **Status:** Living document. Owners must review on every change to the AppleScript or Accessibility surface.
> **Last reviewed:** 2026-05-20 — added OSCAL component definition (STORY-022)
> **Companion artifacts:** `docs/stories/STORY-006-run-applescript-tool.md`, `docs/PRD-MCP-MacOSControl.md`
> **Machine-readable mapping:** [`oscal/component-definition.json`](../oscal/component-definition.json) — OSCAL 1.1.2 Component Definition. See [`oscal/README.md`](../oscal/README.md) for maintenance workflow. CI fails on drift between this document and the OSCAL artifact (see §7.3).

---

## 1. Scope and Audience

This document is the security baseline for **MCP-MacOSControl**, a Model Context Protocol server that exposes macOS automation capabilities (accessibility tree, mouse, keyboard, screen capture, AppleScript, Vision/CoreML) as MCP tools to AI agents.

Audience: engineers contributing to the project, security reviewers, and compliance teams mapping the project's controls to NIST SP 800-53 / FedRAMP / equivalent baselines via OSCAL.

This document covers:
- The trust model under which the server operates
- Attack surfaces by tool family
- The threat catalog and mitigations
- Accepted risks and their justifications
- Mapping to NIST SP 800-53 controls (the OSCAL implementation-layer hooks)
- How to report a vulnerability

This document does **not** cover:
- Threats outside the MCP server's process boundary (host OS hardening, network security, MCP transport security — those are the deployer's responsibility)
- Threats specific to individual MCP host applications (Claude Desktop, Zed, etc.)
- Acceptance of cryptographic primitives, supply-chain attestation, or build-time controls (separate concerns, separate documents)

---

## 2. Trust Model

The MCP server is a **user-space process** running as the macOS user that started it. It has the same filesystem, network, and TCC permissions as that user, no more and no less.

Three actors interact with the server, with different trust levels:

| Actor | Trust | Why |
|---|---|---|
| **The user** (who launched the server) | Trusted | The server runs with their permissions; they accept the risk by launching it. |
| **The MCP host application** (Claude Desktop, etc.) | Trusted by virtue of being local | Communicates over local stdio. The host is responsible for gating tool calls behind user confirmation per its own security model. |
| **The AI agent generating tool calls** | **Untrusted** | The agent's outputs are influenced by the entire context window — including documents, web content, and prior tool results. Prompt-injection attacks make the agent a vector for malicious actions even when no human user intends harm. |

**The central design principle is therefore: the server protects the user from the AI agent, not the other way around.** Tools that take input from the agent must validate, audit, and where possible constrain that input. "The user wouldn't ask for this" is not a defense — the server cannot tell whether a tool call originated with the user's intent or with content injected upstream.

---

## 3. Attack Surfaces by Tool Family

| Tool family | Source | Inputs from agent | Risk profile |
|---|---|---|---|
| **Accessibility tree read** (`accessibility_tree`) | `AccessibilityModule` | App name, window title, depth | Low — read-only, bounded by AX API |
| **Semantic interaction** (`click_element`, `perform_ax_action`) | `AccessibilityModule` (Epic 1) | Element locators, action name | Moderate — can dispatch any AX action including destructive ones |
| **Mouse / keyboard synthesis** (existing) | `MouseModule`, `KeyboardModule` | Coordinates, key codes, text | Moderate — can drive any UI; cannot execute scripts directly |
| **Screen capture & Vision** (existing) | `ScreenCaptureModule`, `VisionModule` | Display/window selectors | Low for capture; moderate for OCR (data exfiltration vector — capture contains visible secrets) |
| **AppleScript execution** (`run_applescript`, `click_menu_item`) | `AppleScriptModule` (Epic 2) | Arbitrary AppleScript source; menu paths | **High** — Turing-complete script execution, broad system access |
| **Window / iPhone Mirroring** | `WindowModule`, `IPhoneMirroringModule` | Window selectors, taps | Low–moderate; iPhone Mirroring inherits the connected phone's TCC posture |

Each tool family has a different mitigation profile. The remainder of this document focuses on the high-risk and moderate-risk surfaces.

---

## 4. Threat Catalog

The following four risk classes are the canonical threat model for the AppleScript surface. They are tracked as the design framing for STORY-006 and STORY-007 and are referenced by the audit-record schema and the OSCAL control mapping in §7.

### 4.1 Arbitrary code execution via AppleScript

**Threat.** A malicious tool call passes script source containing `do shell script "..."`, `do JavaScript "..."` (in any scriptable browser), `load script file "..."`, or `tell application "System Events" to keystroke ...`. AppleScript is Turing-complete and `osascript` runs as the server's user, so any of these primitives is equivalent to local code execution at the user's privilege level.

**Primary mitigation.** `AppleScriptSecurityFilter` (STORY-006). Strict, case-insensitive, whitespace-tolerant regex denylist applied after stripping comments and string literals. Blocks at minimum:
- `do shell script`
- `do JavaScript`
- `load script`
- `tell application "System Events"` (used as a blanket pivot to synthetic input + filesystem)
- Path traversal patterns (`../`, absolute paths to `/etc`, `/private`, `~/.ssh`)

Filter ruleset is owned by the security reviewer and changes go through code review with a security label.

**Secondary mitigations.**
- Mandatory audit hook on every invocation (success, failure, **and rejection**) — see §4.4 mitigations
- macOS TCC automation permissions per target app (§4.3) — additional gate that operates outside the server's control
- MCP host gating — Claude Desktop and most hosts require user confirmation for `destructiveHint: true` tools; `run_applescript` is annotated accordingly

**Accepted residual risk.** The regex denylist is bypassable. Documented bypass classes:
- Reconstruction via runtime string concatenation (`set x to "do shell" & " script \"...\""` then `run script x`) — the filter sees the constructed strings literally, not the eventual evaluation
- Unicode normalization tricks (homoglyphs in keyword positions, though AppleScript itself rejects most of these at parse time)
- Dynamic `run script` with input sourced from `tell application` returns
- Comments split across lines that re-form the keyword after stripping

**Justification for accepting this residual risk:**
1. AST-based filtering would require a production-ready Swift AppleScript parser, which does not exist. Building one is out of scope and would itself introduce new attack surface.
2. The audit hook ensures every invocation — including bypass attempts that succeed against the filter — produces a forensic record. Detection compensates for imperfect prevention.
3. macOS TCC enforces per-app automation permissions independently. Even a bypassed filter cannot reach apps the user has not granted automation permission for.
4. The MCP host's user-confirmation prompt for destructive tools provides a final human gate.

The bypass class is recorded as an accepted risk in the project POA&M (NIST SP 800-53 RA-3 / RA-5 lineage). Re-evaluation criteria: a credible Swift AST parser becomes available, or a post-incident review identifies a bypass exploited in the wild.

### 4.2 Exfiltration via stdout

**Threat.** A script returns sensitive data to the MCP client. Examples: `tell application "Mail" to get content of every message`, `tell application "Keychain Access" to ...`, reading clipboard contents, reading Notes, dumping Safari open tabs and history. The AI agent receives the data in the tool response and may forward it elsewhere.

**Primary mitigation.** Output truncation cap of 1 MB per invocation. Response includes `truncated: true` flag when the cap is hit. Prevents bulk dumps but does not prevent small targeted reads.

**Secondary mitigations.**
- Audit record captures the invocation (script SHA-256, timestamp, target apps) — small targeted reads still leave a trail
- macOS TCC blocks access to apps without granted automation permission
- The MCP host's user-confirmation prompt provides human review of the destination tool's intent

**Accepted residual risk.** A single read of a single secret (e.g., a password from the Notes app, an API key from a clipboard manager) bypasses the truncation cap and leaves only an audit trail, not a prevention.

**Justification:** AI agents have legitimate reasons to read user data on the user's behalf. Distinguishing legitimate from malicious reads requires intent inference the server cannot perform. The user's choice to install and run the server, combined with the MCP host's confirmation gates, is the consent model. The audit trail provides forensics for incident response.

### 4.3 TCC bypass attempts

**Threat.** A script invokes `tell application "X"` for an app the user has not granted automation permission for. Without a pre-flight check, `osascript` hangs on the modal TCC prompt — denial of service in CI, prompt fatigue locally.

**Primary mitigation.** `AutomationPermissionChecker` (STORY-006). Pre-flight check via `AEDeterminePermissionToAutomateTarget`, applied to every statically-extracted `tell application "X"` clause. On denial, returns `automation_permission_required` error naming the target app and explaining the System Settings → Privacy & Security → Automation grant path. `osascript` is not invoked.

**Limitation.** Best-effort: scripts that build app names dynamically (e.g., `tell application name1 & " " & name2`) cannot be statically extracted. The check returns `.skipped` for these, and the runtime TCC prompt becomes the gate.

**Accepted residual risk.** Dynamic-name scripts can still trigger TCC prompts in CI. Mitigated by recommending CI runners pre-grant automation permission for the fixture apps used in integration tests, and by treating TCC prompts in production as an expected user touchpoint, not a failure.

**Defensive posture.** macOS TCC is the primary defense and operates independently of this server. The `AutomationPermissionChecker` is a courtesy that provides better error messages and avoids the hung-process failure mode; it is not the actual access control.

### 4.4 Audit log tampering

**Threat.** A malicious script (or post-incident attacker with local access) modifies or deletes audit records to hide evidence of policy violations.

**Current mitigation (STORY-006 scope).** The `AuditRecorder` protocol seam is committed; the v1 production implementation is `InMemoryAuditRecorder`. Records are not persisted across process restarts.

**Acknowledged gap.** This is the seam, not the production implementation. The in-memory recorder is suitable for development and tests but provides no tamper resistance and no durability. A separate compliance-track story must commit:
- Append-only filesystem sink with rotation, owned by a directory the server's user can write to but not silently truncate
- Optional OpenTelemetry export for organizations with central log aggregation
- Optional syslog / unified-logging emission for macOS-native audit pipelines
- Tamper-evident hashing (each record includes the SHA-256 of the previous record's serialized form)

**Why deferred.** STORY-006 commits the protocol seam — that is the only architectural decision needed to make the production sink swappable. Implementing the production sink now would over-design the v1 code and bury the security-critical execution path under audit infrastructure. The deferral is intentional and the risk is accepted *for development and test environments only*. The production sink is a precondition for any deployment that claims AU-2 / AU-3 implementation under NIST SP 800-53.

---

## 5. Defenses Inherited from macOS

These are not implemented by this project. They are the platform-level defenses that the project's threat model assumes are in place:

- **TCC** (Transparency, Consent, and Control) — enforces per-app permissions for accessibility, automation, screen recording, microphone, camera, full disk access. Required permissions are documented in `docs/PERMISSIONS.md`. The server cannot circumvent TCC; if a tool fails because of TCC, the failure surfaces as a structured error and the user is responsible for granting the permission.
- **Sandbox / hardened runtime** — the server is not currently sandboxed because the tool surface requires accessibility and automation entitlements that are incompatible with strict sandboxing. This is a deliberate architectural choice; alternative deployment patterns (e.g., a sandboxed broker that delegates to a privileged helper) are out of scope.
- **Code signing and notarization** — required for distribution but not enforced by this project's build at present. A future story should add notarized release artifacts to support deployments that require signed binaries.
- **System Integrity Protection (SIP)** — protects core OS files from modification regardless of permissions. The project's denylist patterns covering `/etc`, `/private`, etc. are belt-and-braces in addition to SIP.

---

## 6. Reporting Vulnerabilities

Do not file public GitHub issues for security-sensitive defects.

Preferred path: open a private GitHub Security Advisory at
`https://github.com/aerocristobal/MCP-MacOSControl/security/advisories/new`

Include:
- A description of the vulnerability and the affected tool / component
- A minimal reproduction (script source, tool call payload, observed behavior)
- Your suggested severity and rationale
- Whether you intend to publish a write-up, and on what timeline

The maintainers will acknowledge within 5 business days. Coordinated disclosure timeline is 90 days from acknowledgment unless extenuating circumstances justify extension and you agree.

Do not publish proof-of-concept exploits — including reduced or partial PoCs — before a fix is released and disclosed.

---

## 7. Compliance Mapping (NIST SP 800-53 / OSCAL)

This project is designed so its security-relevant artifacts can be expressed as OSCAL Implementation Layer content (Component Definition + System Security Plan) without retroactive instrumentation. The audit-record schema in particular is structured to satisfy AU-3 content requirements.

Authoring formal OSCAL component-definition entries is **out of scope** for STORY-006 and STORY-007; a separate compliance-track story will produce them. The mapping below is the design input for that future work.

### 7.1 Controls satisfied (or partially satisfied) by this project

| Control | Title | How this project addresses it |
|---|---|---|
| **AC-3** | Access Enforcement | Tool annotations (`destructiveHint`, `readOnlyHint`) signal MCP hosts to apply user-confirmation gates before invocation. macOS TCC is the underlying enforcement mechanism for filesystem and automation access. |
| **AC-4** | Information Flow Enforcement | 1 MB output truncation cap with `truncated: true` flag bounds data egress per invocation. |
| **AU-2** | Event Logging | `AuditRecorder.record(_:)` is invoked on every `run_applescript` and `click_menu_item` call regardless of outcome. |
| **AU-3** | Content of Audit Records | `AuditRecord` schema satisfies "what (toolName), when (timestamp), where (targetApps), source (MCP client metadata when present), outcome (success / failure variant)." Subject identity is the local user (single-tenant by design). |
| **AU-9** | Protection of Audit Information | **Partially satisfied.** Protocol seam committed; production sink with append-only semantics is deferred (see §4.4). |
| **CM-7** | Least Functionality | `AppleScriptSecurityFilter` denylist disables `do shell script` and `do JavaScript` even though `osascript` supports them — the project intentionally exposes a reduced subset of AppleScript's capability surface. |
| **SC-7** | Boundary Protection | Out of scope for the server itself; relevant to deployers configuring MCP transport. |
| **SI-10** | Information Input Validation | `AppleScriptSecurityFilter.validate(_:)` is the validator for AppleScript input. Input schema validation in tool entry points covers structural validation for all tools. |
| **SI-11** | Error Handling | Structured `MCPError` envelope per tool — error codes designed to be actionable (`element_not_found`, `automation_permission_required`, `security_policy_violation`) without leaking internal state. |
| **RA-5** | Vulnerability Monitoring and Scanning | CI runs SCA on every PR via Grype against a CycloneDX SBOM, plus GitHub's native Dependency Review action. See §8 for the full pipeline. |
| **SR-3** | Supply Chain Controls and Processes | `.github/sbom-policy.yml` declares allowed licenses and severity gates; changes are PR-gated under the `security-review` label. See §8.1. |
| **SR-4** | Provenance | CycloneDX 1.5+ SBOM generated by Syft on every push and PR identifies every transitive Swift package by name, version, and SHA. Attached to GitHub Releases on tagged builds. See §8.2. |
| **SR-11** | Component Authenticity | Grype scans the SBOM against the GitHub Advisory Database on every PR; CVSS ≥ 9.0 blocks merge, 7.0–8.9 warns with a PR comment. See §8.3. |

### 7.2 Controls NOT addressed by this project (deployer responsibility)

| Control | Why not |
|---|---|
| **AC-2** Account Management | The server is single-tenant by design — runs as the launching user. Multi-user account management is a deployer / OS concern. |
| **IA-2** Identification and Authentication | MCP transport is local stdio; the connecting host is implicitly trusted by virtue of process boundary. Cross-network MCP deployments require a deployer-supplied authentication layer. |
| **AU-9** (full satisfaction) | Production audit sink is deferred; see §4.4. |
| **SC-8** Transmission Confidentiality and Integrity | MCP stdio is loopback; no transport encryption applied or required. |
| **SC-13** Cryptographic Protection | No cryptographic operations performed by the server other than SHA-256 of script source for audit fingerprinting. |

### 7.3 OSCAL artifacts

1. **Component Definition** — Authored at [`oscal/component-definition.json`](../oscal/component-definition.json) (OSCAL 1.1.2). Every control named in §7.1 and §8 has an `implemented-requirement` block with links to source files (`rel: implementation`) and test files (`rel: verification`). The §7.2 deployer-responsibility controls appear with `implementation-status: not-applicable`. Maintained per STORY-022; see [`oscal/README.md`](../oscal/README.md). Drift between §7/§8 and the OSCAL artifact is enforced by `OscalCoverageCheckerTests` (CI-gated).
2. **Audit Record → OSCAL Observation mapping** — Future work. Each `AuditRecord` is structurally convertible to an OSCAL Assessment Results `observation` for inclusion in an SSP's evidence collection; a generator is out of scope until a downstream SSP author requires it.
3. **POA&M entries** — Future work. The §4.1 bypass classes and the §4.4 deferred audit sink will be POA&M entries with `risk-accepted` status; tracked alongside the OSCAL component definition when a deployer engagement requires the artifact.

Reference: `oscal-engineering-guide.md` (project knowledge base).

---

## 8. Supply Chain Risk Management

This section maps to NIST SP 800-53 controls **SR-3** (Supply Chain Controls and Processes), **SR-4** (Provenance), and **SR-11** (Component Authenticity). It documents the SBOM + SCA + dependency-review pipeline that runs on every push and pull request, and the release-time publication of evidence artifacts.

### 8.1 Policy artifact

`.github/sbom-policy.yml` is the single source of truth for supply-chain policy. It declares:

| Field | Current value | Used by |
|---|---|---|
| `allowed_licenses` | `MIT`, `Apache-2.0`, `BSD-2-Clause`, `BSD-3-Clause`, `ISC` | `dependency-review-action` (`allow-licenses` arg) |
| `severity_gates.block` | `critical` (CVSS ≥ 9.0) | `anchore/scan-action` (`severity-cutoff` arg); fails the workflow |
| `severity_gates.warn` | `high` (CVSS 7.0–8.9) | post-scan SARIF parser; posts a PR comment, does not block |
| `severity_gates.log` | `medium`, `low` | recorded in SARIF only; visible in Security tab |
| `vex_statements_file` | `.github/vex-statements.json` | `release.yml` (attach VEX to release when non-empty) |

Edits to this file route through PR review under the `security-review` label. Re-evaluate the CVSS block threshold after 30 days of operation per §9 Notes in `docs/stories/STORY-021-software-supply-chain-security.md`.

### 8.2 SBOM generation (SR-4)

`.github/workflows/ci.yml` runs `anchore/sbom-action@v0` (Syft under the hood) on every push and PR. The tool parses `Package.resolved` natively and emits a CycloneDX 1.5+ JSON document at `sbom-cyclonedx.json` that names every transitive Swift package by identity, version, and revision SHA. The SBOM is uploaded as a workflow artifact (`sbom-cyclonedx`).

On tagged releases (`v*`), `.github/workflows/release.yml` regenerates the SBOM against the tagged source and attaches it (alongside `vex-statements.json` when non-empty) to the GitHub Release. Consumers who need an authoritative component manifest pull the asset from the release.

### 8.3 SCA and gating (SR-11)

Two scanners run on every PR:

1. **`actions/dependency-review-action@v4`** (PR-only). Native GitHub action, diffs the PR's manifest against the base ref, fails on `severity: critical` and on disallowed licenses. First-line gate; runs in seconds.
2. **`anchore/scan-action@v3`** (Grype). Scans the SBOM against the GitHub Advisory Database, emits SARIF, fails the build on `severity-cutoff: critical`. SARIF is uploaded to the repo's Security → Code scanning tab via `github/codeql-action/upload-sarif@v3`.

A subsequent shell step parses the Grype SARIF for findings with `security-severity` between 7.0 and 8.9 (the `warn` tier per §8.1). When present, it posts a single `gh pr comment` summarizing each CVE with its score. No third-party action is required.

### 8.4 VEX (Vulnerability Exploitability eXchange)

`.github/vex-statements.json` holds CycloneDX VEX 0.5 statements documenting CVEs that are known but **not exploitable** in this codebase, or accepted with mitigation. The initial committed content is `[]` (no statements). Adding a statement is a security-review action that asserts evidence — the requested format and review cadence are documented in `docs/stories/STORY-021-software-supply-chain-security.md` §4 Q5.

The release workflow attaches the VEX document to GitHub Releases only when it is non-empty; an empty placeholder has no signal value on a public release.

### 8.5 Dependency upgrades (Dependabot)

`.github/dependabot.yml` opens monthly PRs for Swift packages and weekly PRs for GitHub Actions. Cadence rationale:

- **Swift packages** move slowly and the project pins exact versions in `Package.resolved`. Weekly upgrade PRs would create churn without payoff.
- **GitHub Actions** ship security fixes more often (and supply-chain attacks against Actions are a real class — see e.g. the `tj-actions/changed-files` incident). Weekly cadence catches these faster.

Dependabot-opened PRs run the full pipeline above, so each upgrade is automatically re-scanned for CVEs and license drift.

### 8.6 Verifying the critical-CVE gate

The gate is exercised in two ways:

1. **Production traffic.** Every PR runs `anchore/scan-action@v3` against the freshly generated SBOM. The first PR after a newly disclosed Critical CVE in any pinned dependency will fail, naming the offending package, CVE ID, and CVSS score in the workflow log. No fixture needed — the live advisory database is the test.
2. **Out-of-band proof on demand.** Open a throwaway feature branch, pin a Swift package version with a known-disclosed Critical CVE (e.g. an old `swift-nio` predating an advisory), push, and confirm the CI's `SCA scan (Grype, STORY-021)` step fails. Discard the branch. Record the run URL in a follow-up PR comment if the gate's correctness ever comes into question.

Synthetic-SBOM unit tests are deliberately not committed: maintaining a fixture with a hard-coded "known-bad" CVE drifts as advisories age and creates a maintenance footgun. The DoD permits manual verification (story §8 Tests bullet) and the production-traffic mode above is the standing assurance.

### 8.7 Accepted risk and known limitations

- **No SBOM signing yet.** STORY-021 commits the artifact but not its attestation. STORY-023 (signing/notarization) will close this loop with `sigstore` / `cosign`.
- **Advisory-database freshness.** Grype's vulnerability database refreshes daily inside the action; a CVE published in the last 24 hours may not be caught on a given PR. Subsequent PRs will pick it up; this is consistent with the rest of the ecosystem.
- **Reachability is not modeled.** A high or critical CVE in a transitive dependency is flagged even if the vulnerable code path is unreachable from this codebase. The `warn`-tier classification (not blocking) for high-severity findings is the explicit compromise; VEX statements are how operators downgrade individual cases after review.
- **Single SBOM format.** CycloneDX only; SPDX is not generated. If a downstream consumer requires SPDX, it is a one-line tool-config change in `sbom-action`.

### 8.8 Cross-references

- `.github/sbom-policy.yml` — current policy values
- `.github/workflows/ci.yml` — PR gate pipeline
- `.github/workflows/release.yml` — tagged-release publication
- `docs/stories/STORY-021-software-supply-chain-security.md` — full BDD acceptance criteria, DoD, and refinement notes
- [`oscal/component-definition.json`](../oscal/component-definition.json) — STORY-022 OSCAL component definition. Links the SBOM as `rel: evidence` (see SR-3 / SR-4 / SR-11 implementation statements).

---

## 9. Operational Guidance

### 9.1 For developers contributing to security-relevant code paths

- Any change to `AppleScriptSecurityFilter`'s ruleset requires a security-labeled review and an updated entry in §4.1's documented bypass classes (additions, removals, or known-bypasses-now-fixed).
- Any change to the `AuditRecord` schema requires updating §7.1 (control mapping) and the future OSCAL component-definition story.
- Any new tool that takes free-form input from the agent — string inputs that aren't enums or fixed-shape structs — must come with a section in §3 (attack surface entry) and an entry in §4 (threat + mitigation) before merge.

### 9.2 For deployers

- Grant the server the minimum macOS TCC permissions actually required for your use case. The server's tool descriptions identify which permission each tool needs.
- Disable the `AppleScriptModule` entirely if your deployment forbids `osascript` execution. The module is structured as a separable unit specifically so this is a one-line change in `Sources/MCP-MacOSControl/main.swift`.
- Provide a production audit sink before deploying outside development. The in-memory recorder is not suitable for production.
- Apply MCP host configuration that requires user confirmation for tools annotated `destructiveHint: true`.

### 9.3 For security reviewers

- The four risk classes in §4 are the authoritative threat catalog. Threats not covered by this catalog are either out of scope (§1) or warrant an addition to the catalog via PR.
- The accepted-risk justifications in §4.1 (regex bypass class) and §4.4 (deferred production audit sink) are the load-bearing ones. Re-evaluation criteria are documented inline.
- The server's own code is the responsibility of this document; the macOS platform defenses (§5) and the deployer's environment (§8.2) are not.

---

## 10. Change Log

| Date | Author | Change |
|---|---|---|
| 2026-05-09 | aerocristobal | Initial draft accompanying STORY-006 (run_applescript). Threat model, NIST SP 800-53 control mapping, and OSCAL roadmap. |
| 2026-05-20 | aerocristobal | Added §8 Supply Chain Risk Management (STORY-021): CycloneDX SBOM via Syft, Grype SCA, GitHub Dependency Review, Dependabot config, VEX placeholder, and SR-3/SR-4/SR-11 mapping in §7.1. §8 Operational Guidance renumbered to §9; Change Log renumbered to §10. |
| 2026-05-20 | aerocristobal | Authored `oscal/component-definition.json` (STORY-022): OSCAL 1.1.2 machine-readable mirror of §7/§8. Adds CI-gated drift detection (`OscalCoverageCheckerTests`) and Docker-pinned `oscal-cli` schema validation. §1 header updated to advertise the OSCAL artifact; §7.3 roadmap updated past-tense; §8.8 cross-references updated. |
