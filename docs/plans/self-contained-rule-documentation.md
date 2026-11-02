# Self-contained rule documentation

Created: 2026-11-02
Last updated: 2026-11-02
Status: Planned
Issue: none
Feature documentation: [rule documentation](../features/rule-documentation.md)

## Problem and intended outcome

Individual rule pages still send readers to aggregate examples and boundaries.
Users should find the examples, relevant configuration, setup, and limitations
for a rule on that rule's page. Remove the aggregate examples document without
losing useful examples or leaving its audit command broken.

## Scope and non-goals

Update documentation PR #54, leaving diagnostic-link behavior in dependent
PR #55 unchanged. Remove generic example/boundary footer redirects, retain
distinct useful examples in the appropriate rule pages, remove stale index
references, and teach the existing development audit to read those pages.
No rule detection, configuration semantics, production dependencies, or editor
extension changes are included. Do not merge either PR.

## Approach and decisions

- Individual `docs/rules/<id>.md` pages are the single source for examples.
  Keep the existing improved primary incorrect/correct pairs; consolidate
  equivalent older examples rather than duplicating them verbatim.
- Preserve distinct scenarios from the old aggregate under the corresponding
  rule, with their required setup and boundaries inline.
- Keep `### Incorrect` and `### Correct` as the primary example pair and JSON
  configuration on each page. Additional scenarios may follow as clearly
  labeled examples without replacing the primary pair.
- Move the example audit to registered rule pages and their documented
  configuration. Keep compiler validation, isolated target-rule checks,
  project fixtures, and real Reanalyze evidence; never silently skip a rule.
- Necessary audit-input changes belong with the documentation change. This
  expands the original Markdown-only scope to documentation plus development
  validation, not runtime behavior.
- Synchronize the dependent branch with an ordinary non-rewriting merge after
  updating PR #54, so PR #55 does not restore removed documentation.

## Implementation steps

- [ ] Compare the aggregate examples with all 124 individual rule pages.
- [ ] Consolidate useful examples and inline essential boundaries, removing
  generic cross-file example/boundary footers.
- [ ] Remove the aggregate examples document and repair indexes/references.
- [ ] Migrate and regression-test the audit's per-rule-page input.
- [ ] Run the audit with the pinned compiler/adapters, validate documentation
  links and inventory, and run `make check`.
- [ ] Consolidate this plan into the existing feature record, preserving the
  original plan and dated scope decision.
- [ ] Update PR #54 and synchronize dependent PR #55 without landing either.

## Validation

Planned commands: focused Node audit-input tests, the existing
`node scripts/examples/audit-rule-examples.mjs BINARY FIXTURE_PROJECT` command
against the pinned compiler/adapters, `make check`, and `git diff --check`.
Check all registered pages for incorrect/correct examples and configuration,
ensure active links resolve, and ensure no tool still reads the removed file.
Record exact actual outcomes and any blockers separately.

## Open questions and remaining work

No unresolved product decisions. Optional deep technical references can remain,
but a reader must not need them to find a rule's examples or understand its
documented supported subset.
