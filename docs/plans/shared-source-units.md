# Shared source-unit construction

Created: 2026-10-22
Last updated: 2026-10-22
Status: Planned
Issue: https://github.com/jderochervlk/rescript-lint/issues/17
Feature documentation: pending

## Problem and intended outcome

Project and dependency loaders duplicate source reading, parsing, stat metadata
construction and ambiguity detection. Share these operations without changing
observable outcomes.

## Scope and non-goals

Share only construction and the `(module name, source kind)` duplicate predicate.
Keep discovery, ordering, overlays, parser caching, exotic-name validation,
containment, symlink policies and boundary diagnostics in their existing loaders.
Do not introduce a generic filesystem framework.

## Approach and decisions

Expose construction and duplicate detection through Project_files, which already
owns the unit type. Construction accepts explicit source-reader and parser
functions; it reads, parses, then stats the original filename. This avoids a new
module/type dependency cycle and keeps overlay selection outside construction.
Retain each scanner rather than parameterizing incompatible security policies.

## Implementation steps

- [ ] Extract construction and expose the duplicate predicate; use both loaders.
- [ ] Add paired implementation/interface, duplicate, metadata, read/stat failure
  regressions and explicit project-skip/dependency-reject symlink assertions.
- [ ] Run focused tests, make check and make coverage; record actual blockers.
- [ ] Promote this plan into feature documentation preserving this original text.
- [ ] Push branch, open PR linking issue, request GitHub Codex review and address
  available findings; return if review remains pending.

## Validation

Planned: `opam exec -- dune exec test/project_index_test.exe`,
`opam exec -- dune exec test/project_errors_test.exe`,
`opam exec -- dune exec test/throws_packages_test.exe`,
`opam exec -- dune exec test/dependency_packages_test.exe`, `make check`,
and `make coverage`. Verify deterministic unit order, allowed interface pairs,
same-kind rejection, source/parse/stat error ordering, metadata, overlay and
cache semantics, and differing symlink policies.

## Open questions and remaining work

The workspace starts with absent `vendor/rescript`; never commit its deletion.
Native tool availability and local dependency setup must be established without
global installations or editing outside the attached workspace.
