# POA&M UUID Allocations

This file is the cross-PR registry of UUIDs assigned to POA&M items and
related milestones. It exists so two PRs cannot race to use the same
identifier and so closed items retain a stable UUID for historical
traceability (assessors cite POA&M items by UUID).

When you add or modify a POA&M item in `oscal/plan-of-action-and-milestones.json`:

1. Generate a v4 UUID (`uuidgen | tr 'A-Z' 'a-z'`) — or for the structured
   pattern used today, a sequence-style ID that's distinct from every
   other entry in this file.
2. Append a row to the table below.
3. Reference the UUID from the POA&M JSON.
4. Do NOT recycle a UUID even if the item is closed — closed items
   retain their UUID for audit-trail continuity.

## Item allocations

| UUID | SECURITY.md section | Title | Status | Allocated by |
|------|---------------------|-------|--------|--------------|
| `11111111-1111-4111-8111-1111111111a1` | §4.1 | AppleScript security filter regex bypass class | risk-accepted | STORY-037 |
| `22222222-2222-4222-8222-2222222222a1` | §4.2 | Single-secret exfiltration via stdout | risk-accepted | STORY-037 |
| `33333333-3333-4333-8333-3333333333a1` | §4.3 | Dynamic-name TCC prompts in CI | risk-accepted | STORY-037 |
| `44444444-4444-4444-8444-4444444444a1` | §4.4 | Audit log: no per-record HSM signing | risk-accepted | STORY-037 |
| `44444444-4444-4444-8444-4444444444c0` | §4.4 (historical) | Deferred production audit sink | closed | STORY-037 |
| `f17c8b39-6f53-4bd1-93d6-c44e1aac9b91` | — (auto-opened) | Audit hash-chain integrity failure | open | STORY-037 |

## Milestone allocations

| UUID | Parent POA&M item | Milestone |
|------|-------------------|-----------|
| `11111111-1111-4111-8111-1111111111b1` | §4.1 | STORY-025 fuzz harness operational |
| `11111111-1111-4111-8111-1111111111b2` | §4.1 | Quarterly re-review of bypass class catalog |
| `22222222-2222-4222-8222-2222222222b1` | §4.2 | Intent-classification feasibility review |
| `33333333-3333-4333-8333-3333333333b1` | §4.3 | Integration-suite TCC pre-grant verification |
| `44444444-4444-4444-8444-4444444444b1` | §4.4 | HSM-signing feasibility review |
| `f17c8b39-6f53-4bd1-93d6-c44e1aac9b92` | chain-break | Incident response: investigate latest chain break |

## Pattern note

Item UUIDs follow `<section-prefix>-...-<suffix>aN` to make the
allocation visually scannable: `1111…` for §4.1, `2222…` for §4.2, etc.
This is convention, not a constraint — random v4 UUIDs are also valid.
The chain-break auto-opened item uses a hashed-namespace UUID that
matches `OscalObservationEmitter.chainBreakRiskUuid` so the emitter and
the POA&M agree on the identifier without coordination at runtime.
