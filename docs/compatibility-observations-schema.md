# Compatibility Observations Schema

**Canonical source:** `docs/compatibility-observations.json`
**Producer:** STORY-012 integration suite (`Tests/MCP-MacOSControlIntegrationTests/Support/ObservationRecorder.swift`)
**Consumer:** STORY-020 catalog generator (`mcp-macos-control-catalog`)

The observations file is a JSON array. Every element records one observation of
which interaction layer the `smart_interact` router actually used for a given
application in a given scenario. The file is committed to the repository — it
travels with the source, diffs cleanly in PRs, and serves as the living-data
substrate for `docs/APP-COMPATIBILITY.md`.

## Row schema

```json
{
  "bundle_identifier": "com.apple.TextEdit",
  "interaction_method": "ax_semantic",
  "macOS_version": "14.5",
  "timestamp": "2026-05-19T22:33:41Z",
  "scenario_name": "Validate interaction method selection across app types",
  "tool": "smart_interact",
  "registry_expectation": "ax_semantic"
}
```

| Field | Required | Type | Notes |
|---|---|---|---|
| `bundle_identifier` | yes | string | Apple reverse-DNS bundle id (e.g. `com.apple.TextEdit`). |
| `interaction_method` | yes | string | One of: `ax_semantic`, `applescript`, `ax_hit_test`, `coordinate_fallback`. Matches the values STORY-010's `InteractionRouter` emits. |
| `macOS_version` | yes | string | `<major>.<minor>` — coarser than `operatingSystemVersionString` so the version matrix is stable across patch versions. |
| `timestamp` | yes | string | ISO-8601 (`YYYY-MM-DDTHH:MM:SSZ`). |
| `scenario_name` | yes | string | The integration scenario that produced the observation. |
| `tool` | no | string | The MCP tool whose call yielded the observation (typically `smart_interact`). |
| `registry_expectation` | no | string | The interaction method STORY-019's registry predicted, populated only when the registry has a definite expectation. |

Unknown extra keys are tolerated by the decoder (forward-compatible).

## Retention

The file is committed and reviewable in PRs, so growth is bounded. Each
`(bundle_identifier, scenario_name)` key keeps the most-recent
**50 rows**; older entries are dropped on the next append. This is enough
context for the catalog generator's persistent-discrepancy rule (last 3 rows)
plus generous historical depth for human review, while keeping the file under
~1 MB at realistic scales.

## How rows enter the file

1. An integration scenario calls `ObservationRecorder.record(scenario:tool:application:observed:registry:)`.
2. The recorder appends one row to `docs/compatibility-observations.json` (or
   wherever `STORY_012_OBSERVATIONS_JSON` points if set), populates
   `macOS_version` from `ProcessInfo.operatingSystemVersion`, and applies the
   50-row-per-key cap.
3. The recorder also `XCTFail`s the test immediately if the observed method
   contradicts the registry's hard expectation for that bundle (defined as
   "registry says `ax_supported = true` ⇒ expect `ax_semantic`").
4. CI fails the integration job if the regenerated `docs/APP-COMPATIBILITY.md`
   or `docs/compatibility-observations.json` differs from the committed copy,
   prompting the maintainer to commit the new rows.

## Hand-edit policy

`docs/compatibility-observations.json` is **not** hand-edited. To add an entry,
add an integration scenario that exercises the application — the recorder
captures the observation automatically. To remove an entry, leave it: stale and
archived rows are preserved so operators can query historical compatibility.
