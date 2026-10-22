# Verify exhaustive configuration setters

Created: 2026-10-22
Last updated: 2026-10-22
Status: Planned
Issue: https://github.com/jderochervlk/rescript-lint/issues/18
Feature documentation: pending

## Problem and intended outcome

Continue existing PR #29 without duplicating its implementation or rewriting
shared history. Verify that every supported key selects only its intended field
and preserves existing configuration semantics.

## Scope and non-goals

Review JSON and CLI dispatch, isolated-field tests, error text, adapters and null
resets, thresholds, path bases, ordering, and precedence. Do not change unrelated
code, commit the absent vendor/rescript submodule, or merge the PR.

## Approach and decisions

Retain direct JSON property branches and the private CLI option variant unless
review identifies a concrete defect. PR #29 predates this follow-up plan; this
plan governs new work and does not claim to precede the original implementation.
Follow the latest PR #36 documentation lifecycle without importing its changes.

## Implementation steps

- [ ] Inspect existing dispatch and regression coverage; fix only proven gaps.
- [ ] Run focused configuration, override, and JSON diagnostic tests.
- [ ] Run make check and make coverage; record exact environmental blockers.
- [ ] Document delivered behavior and preserve this original planning record.
- [ ] Push ordinary follow-up commits to PR #29 and request @codex review.

## Validation

Planned: opam exec -- dune runtest test/config test/integration, make check,
and make coverage. Confirm paths and test aliases before execution. Record
actual checks separately; no test results are claimed yet.

## Open questions and remaining work

The vendor/rescript submodule is absent in the initial workspace. Determine
whether the existing environment supports validation without global installs.
No ownership conflict was visible in PR comments, reviews, or branch history.
