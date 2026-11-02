# Reconcile the diagnostic-link PR

Created: 2026-11-02
Last updated: 2026-11-02
Status: Planned
Issue: none
Feature documentation: [rule links in diagnostics](../features/rule-documentation-links.md)
PR: [#55](https://github.com/jderochervlk/rescript-lint/pull/55)

## Problem and intended outcome

Documentation PR #54 was squash-merged into `main`. PR #55 now targets `main`
but retains the earlier documentation-branch history and has merge conflicts.
Make #55 mergeable while preserving both the landed self-contained rule
documentation and the diagnostic-link implementation.

## Scope and non-goals

Update only the existing `feat/rule-documentation-links` branch. Preserve
the CLI, JSON, and LSP link behavior and the removal of the aggregate examples
file. Do not land #55, push to `main`, rewrite published history, change its
draft status, or introduce unrelated cleanup.

## Approach and decisions

- Fetch the current GitHub `main` and PR head and confirm a clean worktree.
- Merge `origin/main` into the PR branch without an automatic commit, rather
  than rebasing and requiring a force-push.
- Resolve conflicts by preserving the merged documentation and the separate
  diagnostic-link contract, not by blindly selecting an entire side.
- Update the living feature record to reflect that the documentation
  prerequisite has landed, retaining its historical planning records.

## Implementation steps

- [ ] Merge `origin/main` and inspect every conflict.
- [ ] Resolve conflicts and preserve the intended standalone PR diff.
- [ ] Verify the removed aggregate stays absent and no conflict markers remain.
- [ ] Run `DUNE_ROOT=. make check` and `git diff --check`.
- [ ] Consolidate this plan into the feature record with validation results.
- [ ] Push the existing PR branch and confirm GitHub mergeability.

## Validation

Confirm that `origin/main` is an ancestor of the updated branch and that
the diff against `main` contains only diagnostic-link work and its records.
Run the full repository check and inspect the index for unresolved files.
Verify the pushed commit and #55's mergeability without merging the PR.

## Open questions and remaining work

No unresolved design decisions. CI can run normally after the branch update;
passing checks does not authorize landing the PR.
