# Qualified custom use calls

Created: 2026-10-22
Last updated: 2026-10-22
Status: Implemented
Issue: https://github.com/jderochervlk/rescript-lint/issues/32

## Purpose and supported behavior

Namespace-qualified exact `use` calls such as `Hooks.use()` and `One.Two.use()`
are ordinary custom hooks. They must follow normal placement: top level of a
component or custom hook, never conditional, in loops, callbacks, async functions,
default arguments or exception handlers. References are not calls; non-hook names
such as `Hooks.user` remain unchecked.

## Usage

Inside an annotated component, `if enabled {Hooks.use()}` reports
`Do not call hooks conditionally.` Move ordinary hooks to the unconditional
top level.

## Design and boundaries

The existing special paths are classified first: bare `use` and exactly
`React.use` retain their conditional/loop exemption. Other qualified paths ending
in `use`, including `Other.React.use`, are ordinary hooks. This is syntactic
naming policy, not alias, shadowing or cross-file semantic inference.
Function-binding recognition (#31) and uppercase owners (#33) are separate work.
Traversal and messages are unchanged.
See [the rule contract](../rules/RULES.md#reactrules-of-hooks).

## Validation

On 2026-10-22, the focused executable reproduced missing diagnostics before the
fix and passed afterward. The issue fixture adds a blank separator to avoid the
unrelated blank-lines rule. Existing special-use tests remain green.

Commands ran with `OPAMSWITCH=/home/josh/Dev/rescript-linter` (existing tools,
read-only) and `DUNE_ROOT="$PWD"` (isolate Dune from the ancestor checkout):

- `opam exec -- dune exec --root . test/react_rules_of_hooks_test.exe`: passed.
- `opam exec -- dune runtest`: passed.
- `make check`: passed build, formatting, six lint-adapter tests, OCaml lint
  (487 sources, zero findings, 213 justified exceptions), and the full suite.
  The first attempt was blocked by missing Zanuda; after central installation
  of pinned Zanuda 2.1.0, the gate identified stale hook-rule exception lines.
  Updating the two existing line anchors by one restored the unchanged, narrow
  mutation exceptions without weakening policy.
- `make coverage`: passed all per-file gates, 96.65% overall, 100% (169/169)
  for the hooks rule.
- `git diff --check`: passed.

The initial default switch lacked Dune. Without an explicit root Dune selected
the ancestor checkout; `dune runtest test/rules` does not execute this test because
tests are declared in `test/dune`. The focused executable and full root-scoped
suite above are the actual evidence. No packaging checks (no packaging changes)
or global installs.

## Historical planning record

### Qualified custom use calls

Plan created: 2026-10-22
Plan last updated: 2026-10-22

Original committed plan (673685b), preserved verbatim:

```markdown
# Qualified custom use calls

Created: 2026-10-22
Last updated: 2026-10-22
Status: Planned
Issue: https://github.com/jderochervlk/rescript-lint/issues/32
Feature documentation: pending

## Problem and intended outcome

Ordinary custom hooks named `Hooks.use` escape hook-placement checks.
Recognize namespace-qualified `use` calls as ordinary hooks while preserving
the existing special `React.use` and unqualified `use` behavior.

## Scope and non-goals

Change call classification and focused regressions only. No semantic inference,
alias resolution, function-binding recognition (#31), or uppercase-binding
recognition (#33). Preserve existing traversal and diagnostic messages.

## Approach and decisions

After matching the existing special paths, classify any qualified path ending
in `use` as Ordinary. Reuse existing placement checks rather than introduce
a second hook traversal. Nested namespaces follow the same syntactic rule.
Actual React aliases and shadowing remain outside this parser-level contract.

## Implementation steps

- [ ] Reproduce the issue with a regression before changing classification.
- [ ] Add ordinary qualified-use classification and positive/negative tests.
- [ ] Run focused tests, make check, and coverage; record exact blockers.
- [ ] Promote this plan to living feature documentation with its original record.
- [ ] Open a PR and request actual Codex review; report pending feedback honestly.

## Validation

Run `opam exec -- dune runtest test/rules`, `make check`, and `make coverage`.
Test conditional, loop, callback, module-scope, async, handler and default
placement, clean top-level component/custom-hook use, namespace boundaries,
references, and retained special React.use behavior.

## Open questions and remaining work

No design questions. Dependency availability may block local validation;
initialize only workspace-local dependencies and report any remaining blocker.
```

Progress and decisions 2026-10-22: reproduction, classification, regression tests
and documentation completed without scope changes. The initial missing Zanuda
blocker was resolved centrally; exact `make check` then passed after refreshing
the existing mutation-exception line anchors. Codex review of implementation
commit `1b4fa77` completed with no findings. These are historical checks, not
merge authorization.
