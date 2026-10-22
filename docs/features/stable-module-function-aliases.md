# Stable module-function aliases

Created: 2026-10-22
Last updated: 2026-10-22
Status: Implemented
Issue: https://github.com/jderochervlk/rescript-lint/issues/35

## Purpose and supported behavior

`react/exhaustive-deps` recognizes immutable aliases of known module-scope
functions as stable. Capturing such an alias does not require an extra dependency.
Reactive arguments used beside the alias still require dependency coverage.

## Usage

```rescript
module Helpers = {
  @module("./helpers.mjs") external eq: (int, int) => bool = "eq"
}
let useEqual = (~left, ~right) => {
  let eq = Helpers.eq
  React.useMemo(() => eq(left, right), (left, right))
}
```

This example has no exhaustive-deps finding, whether `eq` is called directly or
passed as a function argument.

## Design and boundaries

The render boundary's stable identities include known function values exported
by already-visible modules, recursively. Alias initializers are followed using
the existing semantic expression-to-scope map, so later name or module shadowing
does not alter provenance. Visited identities bound traversal conservatively.
No JavaScript generation is required.

Parameters, render-local closures and their aliases, record fields, call results,
and unresolved module exports remain reactive. Functions in modules created
inside a render are not automatically stable: they may capture render inputs.
Unknown types do not establish module-function stability. Existing global-value
and stable-hook-value handling remains in place.

## Validation

All commands below used the existing tool switch without modifying it:
`OPAMSWITCH=/home/josh/Dev/rescript-linter DUNE_ROOT="$PWD"`.
The default switch lacks Dune; `DUNE_ROOT` is necessary in this nested checkout.
The pinned ReScript submodule was initialized locally, with no submodule change.

- With the original capture predicate temporarily restored, the new external
  module-function alias regression failed: expected zero findings, got one.
- `opam exec -- dune exec test/react_exhaustive_deps_test.exe`: passed all 30
  cases, including 11 added stability, shadowing, and reactive-boundary cases.
- `make test`: passed.
- The issue's CLI invocation, using `opam exec -- dune exec rescript-lint --`
  and the same `--jsx-runtime react-dom --enable-rule react/exhaustive-deps
  --format json` arguments: clean JSON, exit zero, no diagnostics.
- `make check`: passed build, metadata/format checks, six lint-adapter tests,
  OCaml lint (487 sources, zero findings), and the full test suite. The first
  attempt was blocked by missing Zanuda; parent installed pinned Zanuda 2.1.0
  centrally. Existing mutation-exception line numbers were refreshed after code
  moved; exception sites, reasons, and policy are unchanged.
- `make coverage`: passed the per-file and overall 90% gate; overall 96.66%,
  exhaustive-deps 95.37%, semantic support 92.96%.
- `make coverage-tools` was not run because it would modify the external shared
  switch. Its exact required Bisect commit was already installed:
  `7061d643ff492b0045796357ee6917ded21fb1f0`.
- `git diff --check`: passed. npm packaging checks are not applicable.

## Historical planning record

The following is the original plan committed before implementation, preserved
verbatim as historical intent rather than the current contract.

### Original plan

# Stable module-function aliases

Created: 2026-10-22
Last updated: 2026-10-22
Status: Planned
Issue: https://github.com/jderochervlk/rescript-lint/issues/35
Feature documentation: pending

## Problem and intended outcome

`react/exhaustive-deps` incorrectly requires immutable aliases of stable module
functions. Recognize their provenance without exempting reactive aliases or
render-local closures.

## Scope and non-goals

Limit changes to exhaustive-deps classification and focused regression coverage.
Do not broaden callback handling, rewrite shared hook analysis, or change other
rules. Do not infer stability from arbitrary function calls or record members.

## Approach and decisions

Inspect existing semantic binding provenance and reuse its resolution machinery.
Prefer conservative identity-based classification to spelling-based exemptions;
unknown provenance remains reactive. Cover alias chains, shadowing, direct and
higher-order uses, parameters, and locally allocated closures.

## Implementation steps

- [ ] Reproduce the reported diagnostic and inspect semantic provenance.
- [ ] Implement conservative stable alias classification.
- [ ] Add positive and negative boundary regressions.
- [ ] Promote this plan into living feature documentation, preserving this record.

## Validation

Run the focused rule test, `make check`, `make coverage-tools`, and `make coverage`.
Record actual results separately; do not treat unavailable tools as passing.

## Open questions and remaining work

The checkout begins with absent `vendor/rescript`; initialize it locally if needed
and never commit its absence as a deletion. Confirm local OCaml tooling before
choosing how to run checks. Coordinate shared hook-file changes through parent.

### Decisions and progress, 2026-10-22

Implemented the planned conservative identity-based approach. Reused declaration
scopes instead of resolving initializer names at callback use sites; this avoids
shadowing mistakes. Shared changes are limited to stable module-function identity
collection and passing the existing scope map to exhaustive-deps. Parent was
notified about these hooks-file changes. Implementation and regression coverage
are delivered. Parent resolved the initial tool blocker centrally, and the full
local check now passes. GitHub Codex review was requested on PR #39; review state
is tracked on GitHub rather than treated as an implementation guarantee here.
