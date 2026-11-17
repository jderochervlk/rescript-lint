# Audit area 2 review follow-ups

Created: 2026-11-17
Last updated: 2026-11-17
Status: In progress
Issue: https://github.com/jderochervlk/rescript-lint/pull/5 and https://github.com/jderochervlk/rescript-lint/pull/22
Feature documentation: pending

## Problem and intended outcome

Five unresolved review threads on merged PRs #5 and #22 identify two possible
provenance defects and three gaps in the stacked-PR agent guidance. Confirm each
against the current source and current GitHub documentation, add focused
regressions and fixes for confirmed defects, and correct the guidance without
claiming merged fixes before a follow-up is merged.

## Scope and non-goals

Included: dependency signature inference and include provenance in the source
tree analysis; guidance for discovering remote-only stack membership,
noninteractive stack merges, and one-PR submissions; focused tests and living
feature documentation.

Excluded: unrelated review findings, release/backlog/editor documentation,
other contributors' provenance work, resolving the old GitHub review threads,
and landing the follow-up PR.

## Approach and decisions

Treat each thread independently. Preserve the package's declaration provenance
when its namespace resolves self-references; resolve includes from the lexical
scope available at their declaration rather than a later final scope. Keep the
stack guidance grounded in the current GitHub CLI reference and distinguish
remote stack membership from local tracking state. Because checkout of a
remote-only stack can establish local state, do not present it as a
side-effect-free query; when a safe remote-only lookup is unavailable, stop
before ordinary Git fallback and ask for a clean, coordinated checkout or
explicit confirmation.

Use one ordinary follow-up PR because the code, tests, and operational guidance
are independent deliverables that do not depend on one another. Do not resolve
the five existing threads; link the follow-up and describe its unmerged state.

## Implementation steps

- [ ] Reproduce or disprove both provenance findings with current-code tests.
- [ ] Correct each confirmed provenance defect and verify with focused tests.
- [ ] Correct all three actionable stacked-PR guidance gaps using current docs.
- [ ] Document supported behavior and preserve this committed plan as its
      historical planning record.
- [ ] Run focused checks, `make check`, and coverage where relevant; open one
      focused PR without merging it.

## Validation

Acceptance requires regressions demonstrating the package self-namespace and
lexical include-scope behavior, guidance that matches the current GitHub CLI
reference, successful `make check`, and a coverage run if source changes require
it. Record exact commands and results as performed. The local toolchain was not
yet available at planning time; investigate the repository-local Opam switch
before concluding checks are blocked.

## Open questions and remaining work

Determine whether project-local Opam dependencies are available. Confirm exact
source/test harness behavior before implementing either provenance change.
Investigate the current GitHub reference's merge and one-PR submission contracts
and use its documented branch-name checkout behavior to safely address
remote-only membership.
