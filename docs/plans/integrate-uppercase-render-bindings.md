# Integrate uppercase render bindings

Created: 2026-10-31
Last updated: 2026-10-31
Status: Planned
Issue: https://github.com/jderochervlk/rescript-lint/issues/33
Feature documentation: [Render-function recognition](../features/render-function-recognition.md)
Related PR: https://github.com/jderochervlk/rescript-lint/pull/46

## Problem and intended outcome

PR #47 landed the shared dependency constraints and documentation on main.
PR #46 now has an add/add conflict in the same dependency feature document.
Resolve that conflict without changing uppercase render recognition or the
landed release audit, and merge PR #46 only after its fresh required CI passes.

## Scope and non-goals

Merge current main normally and retain the validation records from both
branches. Preserve code, tests, dependency versions, source verification,
release permissions, and existing planning history. Do not rebase, force-push,
publish packages, or weaken required checks.

## Approach and decisions

The merge preview identifies only docs/features/verified-dependency-pins.md
as conflicted. Its PR #46 version includes all of main's content plus the
branch-specific validation paragraph; retain that complete version.
Consolidate this plan into the render-recognition feature's historical record.

## Implementation steps

- [ ] Commit this plan, merge current main, and resolve the documentation conflict.
- [ ] Verify the resolution preserves both branches and changes no implementation.
- [ ] Run focused hooks tests, make check, and whitespace/conflict-marker checks.
- [ ] Record results and preserve this plan in the living feature documentation.
- [ ] Push the branch, wait for current-head required CI, recheck head/base
      freshness and review state, then squash-merge under the existing ruleset.

## Validation

Use the existing compatible switch with
OPAMSWITCH=/home/josh/Dev/rescript-linter and DUNE_ROOT="$PWD".
Run opam exec -- dune exec test/react_rules_of_hooks_test.exe, make check,
and git diff --check. Required hosted CI supplies the final combined coverage,
native builds, packaging, rebuild and installed-package checks on all targets.

## Open questions and remaining work

No product decisions remain. The user explicitly authorized merging this PR
after resolving the conflict and passing CI. Do not bypass review or branch rules.
