# Contributing to MCP-MacOSControl

## Build & test

```bash
swift build              # debug
swift build -c release   # release
swift test               # unit suite (the integration suite auto-skips)
```

The unit suite must stay green on every change. A
`LivingDocumentationGeneratorTests` gate fails the build if a `.feature`
scenario has no mapped unit test — add a `LivingDocumentationMapping.swift`
entry when you add a scenario.

## Accessibility permission (required for the integration suite)

Several tools (the semantic AX layer, `wait_for_ui_event`, `smart_interact`)
need macOS **Accessibility** permission. Unit tests fake the AX bridge and need
no permission. The opt-in integration suite uses the real bridge and does.

Grant it to whatever process runs `swift test`:

1. **System Settings ▸ Privacy & Security ▸ Accessibility**
2. Add (and enable) your terminal — or the IDE/CI agent — that launches
   `swift test`. On macOS 13+ this cannot be scripted non-interactively; it is
   a one-time manual grant per machine.

Verify with: `swift test --filter ErrorCodeContractTests` after
`export CI_MACOS_INTEGRATION=true` — if it *skips* citing missing
Accessibility, the grant did not take effect for that process.

## Running the integration suite

```bash
CI_MACOS_INTEGRATION=true swift test --filter MCP_MacOSControlIntegrationTests
```

- Without `CI_MACOS_INTEGRATION=true`, every integration scenario skips by
  design — never commit a change that makes them *fail* on a runner lacking the
  flag or the permission.
- `requires_iphone_mirroring` and the permission-revocation scenario skip with a
  structured reason on machines without the special setup. That is expected;
  the contracts they assert are also proven by unit tests.
- New error codes: add them to `ErrorCodeBootstrap` **and** add a matching
  `.forcible` or `.environmentGated` entry to
  `Tests/MCP-MacOSControlIntegrationTests/Support/ErrorTriggerManifest.swift`.
  `ErrorCodeContractTests` fails fast if a registered code has no manifest
  entry — 100% coverage is required.

See [docs/INTEGRATION-CI-SETUP.md](docs/INTEGRATION-CI-SETUP.md) for CI runner
provisioning details.

## Conventions

- Use Behavior-Driven Development: feature files in `Tests/.../Features/`,
  scenarios mapped to executable tests.
- Match the surrounding code style; keep changes surgical.
- Sign commits (`git commit -S`); do not add `Co-Authored-By` lines.
