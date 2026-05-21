# OSCAL Artifacts

This directory holds the machine-readable compliance posture for MCP-MacOSControl.
The artifact is consumed by downstream SSP-assembly tooling and by the project's
own drift-detection tests; both treat it as authoritative for NIST SP 800-53
control coverage.

## Files

| Path | Purpose |
|---|---|
| `component-definition.json` | OSCAL 1.1.2 Component Definition. One component (the MCP server), one control-implementation block targeting the NIST SP 800-53 r5 catalog, and one `implemented-requirement` per control documented in `docs/SECURITY.md` §7 and §8. |
| `known-warnings.md` | `oscal-cli` warnings the maintainers have reviewed and accepted. Empty by default; additions require a security-labelled PR. |

## Maintenance workflow

The OSCAL artifact and `docs/SECURITY.md` are maintained **separately**. The
prose is authored for human reviewers; the OSCAL artifact is authored for
machine consumers. A CI drift check catches divergence in either direction:

- If `SECURITY.md` names a control (e.g. **NEW-X**) that `component-definition.json`
  does not implement → the `OscalCoverageCheckerTests` `missingControls` test
  fails with the offending control id.
- If `component-definition.json` implements a control that `SECURITY.md` does
  not reference → the `extraControls` test fails. (Recovery: either remove the
  OSCAL statement or add the prose mention.)

### When to update the OSCAL artifact

Update `component-definition.json` whenever any of the following lands:

1. A new control is mapped in `docs/SECURITY.md` §7.1 or §8.x.
2. A documented control changes implementation status (e.g. a `partial` becomes `implemented`).
3. A source file referenced by an `implementation` link is renamed or removed.
4. A new accepted residual risk is added to `SECURITY.md` §4 (record as a
   `statements[]` entry with `remarks` under the corresponding control,
   following the SI-10 pattern).

### Update mechanics

1. Edit `component-definition.json`.
2. Bump `metadata.last-modified` to the current UTC timestamp
   (`date -u +"%Y-%m-%dT%H:%M:%SZ"`).
3. Bump `metadata.version` if the change is consumer-visible (added/removed
   controls, changed `implementation-status`). Pure prose tweaks keep the
   version.
4. Generate fresh UUIDs for any new `implemented-requirement` or `statement`
   (`uuidgen | tr 'A-Z' 'a-z'`).
5. Validate locally:
   ```bash
   docker run --rm -v "${PWD}:/work" -w /work \
     ghcr.io/metaschema-framework/oscal-cli:latest \
     validate oscal/component-definition.json
   ```
6. Run the drift tests:
   ```bash
   swift test --filter Compliance
   ```
7. Commit the OSCAL artifact in the same PR as the `SECURITY.md` change that
   prompted it. CI will fail if you split them.

## Schema reference

- OSCAL Component Definition JSON schema (v1.1.2):
  `https://pages.nist.gov/OSCAL-Reference/release-assets/v1.1.2/oscal_component-definition_schema.json`
- NIST SP 800-53 Rev 5 catalog (`source` field):
  `https://raw.githubusercontent.com/usnistgov/oscal-content/main/nist.gov/SP800-53/rev5/json/NIST_SP-800-53_rev5_catalog.json`
- Concepts and outline:
  `https://pages.nist.gov/OSCAL/learn/concepts/layer/implementation/component-definition/`

## Out of scope (future work)

- **System Security Plan** (`system-security-plan.json`) — different stakeholder
  (deployer), different document; not committed here.
- **Plan of Action & Milestones** (`poam.json`) — the §4.1 bypass classes and
  the §4.4 deferred audit sink will be POA&M entries with `risk-accepted`
  status when a deployer requires them.
- **Assessment Plan / Assessment Results** — produced by the consuming SSP
  author, not by this repository.
