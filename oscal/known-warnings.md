# Known OSCAL CLI Warnings

This file documents `oscal-cli validate` warnings the maintainers have reviewed
and accepted for `oscal/component-definition.json`. The CI step that runs the
validator surfaces warnings without failing the build; a warning added to this
catalogue is a deliberate decision and should reference the PR that introduced it.

## Format

Each entry MUST include:

- The warning text (or a stable identifier from the validator output)
- The OSCAL element that triggered it (`implemented-requirement.uuid`, `statement.statement-id`, etc.)
- A justification — why this warning is acceptable for this project
- The PR that ratified the acceptance

## Current entries

_(none — initial state)_
