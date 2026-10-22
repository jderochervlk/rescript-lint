# Empty project discovery

Created: 2026-10-22
Last updated: 2026-10-22
Status: Planned
Issue: https://github.com/jderochervlk/rescript-lint/issues/34
Feature documentation: pending

## Problem and intended outcome

Aggregating workspace roots can select no files and silently appear clean.
Make that selection visible and expose a checked-file count.

## Scope and non-goals

Cover lint, fix, and watch reports and explicit workspace selection guidance.
Do not discover dependencies implicitly or add workspace configuration.

## Approach and decisions

Preserve exit status 0 for empty successful discovery for compatibility.
Add a human stderr warning and structured JSON warnings, preserving schema
version 1 with additive fields. Count successfully checked files, including
files with findings but excluding checks returning errors. Discovery and command
errors count zero. Empty explicit input without project discovery is unchanged.

## Implementation steps

- [ ] Add report count and empty-project warning across reporters and runner.
- [ ] Add focused CLI, JSON, and watch regressions.
- [ ] Document workspace selection and migrate this plan to feature documentation.

## Validation

Run focused CLI tests, then `make check` and `make coverage`. Verify counts for
clean, finding, and failed files and warning behavior across lint/fix/watch.
Record actual outcomes separately; do not commit missing submodule deletions.

## Open questions and remaining work

No unresolved product decisions. Dependency checkout and build tools may block
local validation; do not install global tools.
