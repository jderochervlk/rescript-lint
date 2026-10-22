# Exact use hook bindings

Created: 2026-10-22
Last updated: 2026-10-22
Status: Implemented
Issue: https://github.com/jderochervlk/rescript-lint/issues/31

## Purpose and supported behavior

Function bindings named exactly `use` are custom-hook owners for
`react/rules-of-hooks`. For example:

```rescript
let use = () => {
  let (value, _) = React.useState(() => 0)
  value
}
```

Unconditional ordinary hooks in this body are accepted. Conditional and loop
calls remain invalid, as do hooks in nested ordinary callbacks, async functions,
default arguments, and non-function initializers.

## Design and boundaries

Only `binding_owner` changes: exact `use` joins the existing hook-name convention.
Type-constrained and module-local bindings reuse existing traversal. Near-miss
names such as `useful` do not become hook owners. This fix does not change call
classification: only bare `use` and `React.use` have the special conditional/loop
exemption, not custom qualified `Other.use`. The separately delivered
[qualified-call recognition](qualified-custom-use.md) (#32) classifies
`Other.use` as an ordinary hook. Its conditional call inside an exact-`use`
owner remains invalid. Uppercase recognition (#33) remains separate work.
See the [rule contract](../rules/RULES.md#reactrules-of-hooks) for limitations.

## Validation

2026-10-22: Added focused acceptance, rejection, and conditional-message
regressions in `test/rules/pedantic/react_rules_of_hooks_test.ml`, including the
issue example. Validation used the existing development toolchain with:

```sh
export OPAMSWITCH=/home/josh/Dev/rescript-linter DUNE_ROOT="$PWD"
opam exec -- dune exec test/react_rules_of_hooks_test.exe
make check
make coverage
```

- Reproduced against the unchanged owner predicate: the issue example, module and
  constrained owners, special API body, and conditional message regressions fail.
  The focused executable passes after the fix.
- `make check`: passed build, formatting, lint adapter tests (6), OCaml lint
  (487 sources, 0 findings), and full tests.
- `make coverage` before main integration: passed; hooks module 100% (170/170), overall 96.65%
  (8905/9214), all implementation files meet the 90% gate.
- `git diff --check`: passed.

Initial attempts without the environment failed because default Opam had no
Dune. Explicit-switch attempts then exposed the absent pinned parser and ancestor
Dune root discovery. Restoring only the pinned `vendor/rescript` revision
`679406560d169f1124653ab50795d5077570f078` and setting `DUNE_ROOT` resolved these.
Normal submodule clone timed out; a depth-one fetch of that SHA and detached
checkout succeeded. The gitlink is unchanged. After fixing test formatting,
`make check` exposed line-pinned mutation exceptions displaced by two lines;
only those existing site coordinates were refreshed, without changing policy.
The parent supplied the pinned Zanuda toolchain; this worker installed nothing
globally and edited no external checkout. npm packaging checks do not apply.

## Historical planning record

Original plan committed as `20b11a8` before implementation; preserved verbatim
below as historical intent, not a second current contract.

### Exact use hook bindings

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

### Dated implementation decisions and progress

2026-10-22: Implemented owner-only recognition and focused tests; promoted this
plan to feature documentation. Initial environment blockers were resolved and
focused tests, full checks, and coverage passed. Existing mutation exception
coordinates were refreshed after the owner predicate added two lines.
Remaining delivery work is PR publication and GitHub Codex review.

2026-10-22 integration: PR #40's original head `9643418` passed all six CI
checks and actual GitHub Codex review without findings. After PR #37 delivered
qualified-call recognition on `main` (`e9c49fd`), merged that main normally.
Preserved both the qualified-call classifier and exact-`use` ownership; combined
the rule-reference paragraphs and refreshed the unchanged mutation exceptions
to lines 233/239. Updated the earlier qualified-use boundary regression to
assert an ordinary conditional-call violation inside an exact-`use` owner.
Combined-head validation with the same exported environment passed the focused
hooks executable, exact `make check`, and exact `make coverage`. Combined
coverage is 100% (171/171) for hooks and 96.64% (8897/9206) overall, with every
implementation file meeting the gate. Renewed Codex review is pending.

2026-10-22 final integration: merged `main` through independent CLI/reporting
PR #41 (`32effb3`) normally, without hook-rule conflicts or semantic changes.
With the same environment, the focused hooks executable, exact `make check`,
and exact `make coverage` all passed again. Hooks remain 100% (171/171);
overall coverage is 96.63% (8911/9222), and all per-file gates pass.
The final integrated head is submitted for fresh CI and Codex review.
