# Integration Suite — CI Runner Provisioning (STORY-012)

The End-to-End Integration Validation Suite (`MCP-MacOSControlIntegrationTests`)
drives real macOS apps through the real `ToolRouter`. It is **opt-in** and
**not run per-PR** — see `.github/workflows/ci-integration.yml` (merge to `main`
+ nightly + `workflow_dispatch`).

## What the suite requires

| Requirement | Why |
|---|---|
| `CI_MACOS_INTEGRATION=true` | Master opt-in. Without it every integration test skips (so `swift test` on PRs stays green). |
| A logged-in macOS GUI session | TextEdit/Calculator/the harness app need a `loginwindow` session — not the default ephemeral runner state. |
| Accessibility permission for the `swift test` (xctest) process | The semantic AX layer and `wait_for_ui_event` require it. |
| Pre-installed apps: TextEdit, Finder, Safari, Calculator, Script Editor | GitHub Actions `macos-15` images ship these by default. |
| The `AXDegradedHarness` executable | Built automatically by `swift build --build-tests` as a package target. |

## The Accessibility grant problem (macOS 13+)

`tccutil` can **reset** a TCC entry but **cannot grant** one on macOS 13+ — the
grant requires user interaction or a TCC database write by a process Apple
trusts. There is no supported one-liner. Viable runner strategies:

1. **Pre-provisioned image (recommended).** Bake the Accessibility grant for the
   xctest tool / the runner's shell into a custom runner image so it persists
   across jobs. The workflow's `tccutil reset` step then gives a clean,
   reproducible slate while the baked grant remains.
2. **Signed grant helper.** Install a developer-signed helper at
   `/usr/local/bin/mcp-tcc-grant` that performs the privileged TCC write. The
   workflow invokes it in the *Provision Accessibility grant* step. Absent the
   helper, the suite still runs — permission-dependent scenarios skip with a
   structured reason rather than failing.

If neither is present, the suite degrades gracefully: `IntegrationTestCase`
skips every scenario with a documented reason (it never turns CI red for a
missing grant), so a misprovisioned runner is visible as "all skipped", not as
failures.

## Optional, runner-specific capabilities

| Capability | Env / marker | Behavior when absent |
|---|---|---|
| Live TCC revocation (PermissionRevocationTests) | `MCP_ALLOW_TCC_REVOCATION=1` + signed helper at `/usr/local/bin/mcp-tcc-revoke` | Scenario skips with a documented reason; contract proven by STORY-016 unit tests. |
| iPhone Mirroring (IPhoneSmokeTests) | macOS 15 + paired, calibrated iPhone | Scenario skips (tagged `requires_iphone_mirroring`) with a structured reason. |

## Running locally

```bash
# 1. Grant Accessibility to your terminal / the process that runs swift test:
#    System Settings ▸ Privacy & Security ▸ Accessibility
# 2. Run the suite:
CI_MACOS_INTEGRATION=true swift test --filter MCP_MacOSControlIntegrationTests
```

Set `STORY_012_OBSERVATIONS_JSON=/path/to/out.json` to control where the
interaction-method observations artifact (the STORY-020 catalog feed) is
written; it defaults to a file under the temp directory.

## Timeouts

- Per-scenario: **60 s** (`executionTimeAllowance` in `IntegrationTestCase`).
- Whole job: **15 min** (`timeout-minutes` in the workflow).

A scenario that exceeds its cap fails rather than blocking CI — a hung wait is a
bug, not a reason to stall the pipeline.
