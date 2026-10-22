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
