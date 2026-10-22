# Exact use hook bindings

Created: 2026-10-22
Last updated: 2026-10-22
Status: Planned
Issue: https://github.com/jderochervlk/rescript-lint/issues/31
Feature documentation: pending

## Problem and intended outcome

A function binding named exactly `use` is currently treated as an ordinary
function, incorrectly rejecting unconditional hooks in its body. Recognize this
binding as a custom-hook owner while retaining ordinary placement restrictions.

## Scope and non-goals

Change owner recognition only. Qualified call recognition (#32), uppercase
recognition (#33), and custom-call special React `use` exemptions are not in scope.
Do not stage the pre-existing missing `vendor/rescript` deletion.

## Approach and decisions

2026-10-22: Extend the binding-owner predicate instead of the shared call-name
predicate. This keeps definition ownership separate from special call semantics.
Coordinate common rule/test file changes through the parent.

## Implementation steps

- [ ] Reproduce with focused tests for exact-use owners and invalid contexts.
- [ ] Extend owner recognition without changing call classification.
- [ ] Promote this plan to living feature documentation, preserving this record.
- [ ] Commit, push, open a PR, and request GitHub Codex review.

## Validation

Planned: focused hooks tests, `make check`, and `make coverage`. Cover accepted
unconditional calls, conditional ordinary-hook violations, ordinary-function and
nested-function rejection, and existing special-use boundaries. Record actual
outcomes separately; do not install tools globally.

## Open questions and remaining work

Check toolchain and pinned parser availability; report exact blockers.
