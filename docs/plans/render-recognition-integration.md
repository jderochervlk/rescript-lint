# Integrate annotation-based render recognition documentation

Created: 2026-10-22
Last updated: 2026-10-22
Status: Planned
Issue: https://github.com/jderochervlk/rescript-lint/issues/33
Feature documentation: [Render-function recognition](../features/render-function-recognition.md)
Related PR: https://github.com/jderochervlk/rescript-lint/pull/43

## Problem and intended outcome

PR #43 has a documentation conflict with the hook naming and ownership changes
that landed in PRs #37 and #40. Preserve those changes and the user's decision
to retain annotation-based component recognition, without a new lint rule or
uppercase-name inference.

## Scope and non-goals

Normally merge current `main`, reconcile the rule-reference conflict, and
verify the combined documentation and existing regressions. Do not change rule
implementation, annotations, dependency versions, or validation policies.

## Approach and decisions

The component-recognition contract must retain the supported annotations and
exact-`use` custom-hook ownership from `main`. Add PR #43's guidance about
unannotated render functions and annotation code-generation effects beside it.
Preserve the original plan and record this integration in the living feature
document. No history rewriting or force push.

## Implementation steps

- [ ] Merge current `main` normally and resolve only the documented conflict.
- [ ] Check that both hook fixes and all render-recognition regressions remain.
- [ ] Run focused hooks tests, exact `make check`, coverage, and link checks.
- [ ] Consolidate this plan into the existing feature's historical record.
- [ ] Push the integration and obtain current-head CI and Codex rereview.

## Validation

Planned commands use the existing tools without modifying their switch:
`OPAMSWITCH=/home/josh/Dev/rescript-linter DUNE_ROOT="$PWD"`.
Run `opam exec -- dune exec test/react_rules_of_hooks_test.exe`,
`make check`, `make coverage`, and `git diff --check`. Restore only the exact
pinned parser checkout inside this worktree if it is missing.

## Open questions and remaining work

No product decisions remain. Merge only after exact-head CI passes, actual
Codex review completes, all comments are addressed and resolved, and a fresh
pre-merge check confirms the intended head.
