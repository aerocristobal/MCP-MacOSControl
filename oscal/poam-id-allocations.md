# POA&M UUID Allocations

This file is the cross-PR registry of UUIDs assigned to OSCAL POA&M risks,
poam-items, milestones, risk-log entries, and remediations. It exists so
two PRs cannot race to use the same identifier and so closed entries retain
a stable UUID for historical traceability (assessors cite POA&M data by
UUID).

When you add or modify a Risk, POA&M item, or milestone in
`oscal/plan-of-action-and-milestones.json`:

1. Generate a v4 UUID (`uuidgen | tr 'A-Z' 'a-z'`) — or for the structured
   pattern used today, a sequence-style ID that's distinct from every
   other entry in this file.
2. Append a row to the appropriate table below.
3. Reference the UUID from the POA&M JSON.
4. Do NOT recycle a UUID even after closure — closed entries retain
   their UUID for audit-trail continuity.

## Document-level allocation

| UUID | Element | Notes |
|------|---------|-------|
| `11111111-0000-4000-8000-0000000000aa` | `plan-of-action-and-milestones.uuid` | Document identifier |
| `22222222-0000-4000-8000-0000000000ab` | `assessment-results.uuid` | AR document identifier (companion artifact) |
| `33333333-0000-4000-8000-0000000000ac` | `assessment-results.results[0].uuid` | Continuous-monitoring result envelope (AR) |

## Risk allocations

| UUID | SECURITY.md section | Title | Status |
|------|---------------------|-------|--------|
| `11111111-1111-4111-8111-1111111111a1` | §4.1 | AppleScript security filter regex bypass class | deviation-approved |
| `22222222-2222-4222-8222-2222222222a1` | §4.2 | Single-secret exfiltration via stdout | deviation-approved |
| `33333333-3333-4333-8333-3333333333a1` | §4.3 | Dynamic-name TCC prompts in CI | deviation-approved |
| `44444444-4444-4444-8444-4444444444a1` | §4.4 | Audit log: no per-record HSM signing | deviation-approved |
| `44444444-4444-4444-8444-4444444444c0` | §4.4 (historical) | Deferred production audit sink | closed |
| `f17c8b39-6f53-4bd1-93d6-c44e1aac9b91` | — (auto-opened) | Audit hash-chain integrity failure | open |

## POA&M item allocations

The OSCAL POA&M model splits accepted-risk content across two arrays:
substantive state lives on the Risk; the POA&M item is the short
tracking handle that references the Risk via `related-risks`.

| UUID | References risk | Title |
|------|-----------------|-------|
| `11111111-1111-4111-8111-1111111111e1` | §4.1 | Track accepted risk: AppleScript regex filter bypass |
| `22222222-2222-4222-8222-2222222222e1` | §4.2 | Track accepted risk: Single-secret exfiltration via stdout |
| `33333333-3333-4333-8333-3333333333e1` | §4.3 | Track accepted risk: Dynamic-name TCC prompts in CI |
| `44444444-4444-4444-8444-4444444444e1` | §4.4 | Track accepted risk: Audit log no per-record HSM signing |
| `44444444-4444-4444-8444-4444444444c3` | §4.4 historical | Track closed risk: Deferred production audit sink |
| `f17c8b39-6f53-4bd1-93d6-c44e1aac9b95` | chain-break | Track open risk: Audit hash-chain integrity failure |

## Milestone, remediation, and risk-log allocations

| UUID | Parent risk | Element |
|------|-------------|---------|
| `11111111-1111-4111-8111-1111111111b1` | §4.1 | Milestone: STORY-025 fuzz harness operational |
| `11111111-1111-4111-8111-1111111111b2` | §4.1 | Milestone: Quarterly re-review of bypass class catalog |
| `11111111-1111-4111-8111-1111111111c1` | §4.1 | Risk-log: Risk accepted by security owner |
| `11111111-1111-4111-8111-1111111111d1` | §4.1 | Remediation: Compensating monitoring plan |
| `22222222-2222-4222-8222-2222222222b1` | §4.2 | Milestone: Intent-classification feasibility review |
| `22222222-2222-4222-8222-2222222222c1` | §4.2 | Risk-log: Risk accepted by security owner |
| `22222222-2222-4222-8222-2222222222d1` | §4.2 | Remediation: Intent-classification feasibility track |
| `33333333-3333-4333-8333-3333333333b1` | §4.3 | Milestone: TCC pre-grant verification on CI runners |
| `33333333-3333-4333-8333-3333333333c1` | §4.3 | Risk-log: Risk accepted by security owner |
| `33333333-3333-4333-8333-3333333333d1` | §4.3 | Remediation: Integration-suite TCC pre-grant verification |
| `44444444-4444-4444-8444-4444444444b1` | §4.4 | Milestone: HSM-signing feasibility review |
| `44444444-4444-4444-8444-4444444444c1` | §4.4 | Risk-log: Risk accepted by security owner |
| `44444444-4444-4444-8444-4444444444c2` | §4.4 historical | Risk-log: Risk closed (STORY-024 shipped) |
| `44444444-4444-4444-8444-4444444444d1` | §4.4 | Remediation: HSM-signing feasibility track |
| `f17c8b39-6f53-4bd1-93d6-c44e1aac9b92` | chain-break | Task (action): Incident response — investigate latest chain break |
| `f17c8b39-6f53-4bd1-93d6-c44e1aac9b93` | chain-break | Risk-log: Risk opened (template) |
| `f17c8b39-6f53-4bd1-93d6-c44e1aac9b94` | chain-break | Remediation: Operator incident response on chain break |

## Pattern note

Risk UUIDs follow `<section-prefix>-…-<suffix>aN` to make the
allocation visually scannable: `1111…` for §4.1, `2222…` for §4.2, etc.
This is convention, not a constraint — random v4 UUIDs are also valid.
The chain-break auto-opened risk uses a hashed-namespace UUID that
matches `OscalObservationEmitter.chainBreakRiskUuid` so the emitter and
the POA&M agree on the identifier without runtime coordination.

POA&M item UUIDs end in `eN` (vs. risks' `aN`) to make it obvious at
a glance which array an identifier belongs to.

All UUIDs are v4-shape (13th hex == `4`, 17th hex ∈ `89AB`) per the
NIST OSCAL UUIDDatatype pattern. The strict OSCAL validator (CI step)
rejects any UUID that doesn't conform.
