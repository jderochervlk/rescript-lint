# Reconcile current status documentation

Created: 2026-11-17
Last updated: 2026-11-17
Status: Planned
Issue: none
Feature documentation: pending

## Problem and intended outcome

Canonical project status, contribution guidance, and the unsafe API inventory
contain historical release claims as if they were current or future behavior.
Update only those owned documents against the current checkout and dated live
registry/repository evidence, while retaining genuine analysis limitations and
historical implementation context.

## Scope and non-goals

Update `docs/planning/FOLLOW_UPS.md`, `docs/planning/PLAN.md` as needed,
`CONTRIBUTING.md`, and `docs/rules/UNSAFE_APIS.md`. Add the required living
feature documentation for this documentation-maintenance behavior.
Do not edit editor docs, release docs, automatic alpha staging docs or its plan,
source code, or unrelated documentation.

## Approach and decisions

Keep active follow-ups separate from completed/historical milestones. Phrase
registry tag and release facts as an observation dated 2026-11-17, cite the npm
registry endpoint, and avoid presenting a mutable tag/version as a perpetual
latest. Describe current integration repositories and native targets with
repository links. Retain the unsafe-analysis limitations only where they remain
true; remove module alias/open limitations already addressed.

## Implementation steps

- [ ] Commit this plan before changing the status documentation.
- [ ] Reconcile release status, follow-ups, and roadmap milestones to current
  checkout and live evidence.
- [ ] Correct contributor target/CI statements and unsafe API analysis limits.
- [ ] Record delivered documentation policy in feature documentation and update
  this plan with results.
- [ ] Run documentation/link checks and `make check` if applicable.
- [ ] Review scope and open an independent PR without merging.

## Validation

Acceptance: only the scoped documentation changes are present; internal links
resolve; dynamic external release facts have an observation date; no stale
current-state claims remain in the owned documents.

Planned: link/reference check, `git diff --check`, and repository-required
`make check` unless an environment blocker makes it inapplicable or impossible.
Record exact commands and outcomes after running them.

## Open questions and remaining work

None. Public release facts observed from the npm registry on 2026-11-17:
`alpha` is `0.1.0-alpha.22`, `latest` is `0.1.0-alpha.1`; package metadata
includes five native targets (Linux glibc x64/ARM64, macOS x64/ARM64, Windows
x64). Verify repository integration names and links before documenting them.
