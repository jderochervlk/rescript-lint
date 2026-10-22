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
