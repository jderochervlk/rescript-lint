# Uppercase render-function recognition

Created: 2026-10-22
Last updated: 2026-10-22
Status: Blocked on policy approval
Issue: https://github.com/jderochervlk/rescript-lint/issues/33
Feature documentation: pending

## Problem and intended outcome

Escaped uppercase render-function bindings currently require component annotations
that may trigger compiler code generation. Allow designated raw props render
functions to use unconditional hooks while continuing to check conditional calls
and nested callbacks.

## Scope and non-goals

Change only render-function ownership recognition, its focused tests, and its
documented contract. Do not change hook callee recognition, callback traversal,
control-flow analysis, suppression policy, compiler behavior, or dependencies.
Other workers own issues #31 and #32.

## Approach and decisions

The current owner classifier accepts component annotations and custom-hook names.
Recommend recognizing simple bindings beginning with ASCII uppercase letters,
including escaped identifiers, in the existing owner classifier. This matches the
React naming convention without adding annotation syntax. It also treats ordinary
uppercase helpers as component candidates; this is a deliberate contract change,
not proof that the function renders React.

An explicit lint-only annotation would avoid that naming-policy tradeoff but adds
a new public designation mechanism. Parent approval is required before choosing
either approach. Preserve existing per-function restrictions and callback resets.
Do not grant ownership to arbitrary initializer expressions or destructuring.

## Implementation steps

- [ ] Obtain parent approval of recognition policy.
- [ ] Extend the narrow owner classifier without changing traversal.
- [ ] Add positive raw-props/typed-binding cases and negative lowercase,
      conditional, nested callback, async, initializer, and destructuring cases.
- [ ] Update the rule contract and promote this plan into living feature docs,
      preserving this original planning record and creation date.

## Validation

Planned: focused `opam exec -- dune runtest test/rules/pedantic`, `make check`,
and `make coverage`. Inspect the final diff and commit only task-owned files.
No implementation checks have run yet.

## Open questions and remaining work

Await parent decision on uppercase naming versus explicit lint-only designation.
The pre-existing `vendor/rescript` deletion must not be committed or repaired.
Do not install global tools. Push the unique branch without force, open a PR
against main, request Codex review, and hand pending review back to the parent.
