# Verify exhaustive configuration setters

Created: 2026-10-22
Last updated: 2026-10-22
Status: Blocked
Issue: https://github.com/jderochervlk/rescript-lint/issues/18
Feature documentation: [Configuration setters](../features/exhaustive-config-setters.md)

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

- [x] Inspect existing dispatch and regression coverage; fix only proven gaps.
- [x] Run focused configuration, override, and JSON diagnostic tests.
- [x] Run make check and make coverage; record exact environmental blockers.
- [x] Document delivered behavior and preserve this original planning record.
- [x] Push ordinary follow-up commits to PR #29 and request @codex review.

## Validation

Planned: opam exec -- dune runtest test/config test/integration, make check,
and make coverage. Confirm paths and test aliases before execution. Record
actual checks separately; no test results are claimed yet.

## Open questions and remaining work

The vendor/rescript submodule is absent in the initial workspace. Determine
whether the existing environment supports validation without global installs.
No ownership conflict was visible in PR comments, reviews, or branch history.

## Progress and dated decisions

### 2026-10-22

The sections above retain the original committed plan's scope, decisions, and
intended validation; only status, feature link, and progress boxes were updated.
The original implementation was already present in c21323c, authored by
jderochervlk. Its Codex review completed without inline findings. No additional
implementation was justified by static review. Merged fetched main (59850f4)
with a normal merge commit, without rebasing or rewriting the existing PR.

The planned directory-level test command was replaced after inspecting
`test/dune`: tests use `include_subdirs unqualified` and executable targets at
the test root. Attempted:

```sh
opam exec -- dune build test/config_file_test.exe test/rule_config_test.exe test/rule_overrides_test.exe test/json_diagnostics_test.exe
make check
make coverage
```

All three stopped immediately with `[ERROR] Command not found 'dune'`.
The four planned `dune exec` commands were chained after the focused build and
therefore did not run. No native test, format, lint, or coverage result is
claimed. Opam selects `default`; no repository-local `_opam` exists. The missing
vendor/rescript submodule is an additional prerequisite, not the observed first
failure. No tools were installed or files outside this workspace edited.

`git diff origin/main...HEAD --check` passed before this documentation update.
The original PR's Windows npm job failed; that historical result must not be
represented as green CI. Packaging is unchanged, so npm packaging commands were
not run locally. Remaining work is native validation in a provisioned isolated
workspace and a fresh GitHub Codex review on the pushed follow-up head.

### 2026-10-22: provisioned-tool retry

The parent identified an existing dependency switch. Used its installed tools
read-only, without editing the outside checkout or installing anything:

```sh
export OPAMSWITCH=/home/josh/Dev/rescript-linter DUNE_ROOT="$PWD"
```

Restored vendor/rescript at the unchanged pinned gitlink inside this isolated
workspace. Initial `git submodule update --init vendor/rescript` timed out during
clone; a retry could not find its revision. Recovered by fetching only the pinned
679406560d169f1124653ab50795d5077570f078 revision and checking it out detached.
No vendor files or gitlink changes are staged.

The focused build succeeded with `opam exec -- dune build --root .` and the four
executable targets listed above. Running `dune exec` from the repository root
initially failed the rule-config fixture checks because they expect the test
directory as cwd. Corrected to the suite's intended working directory:

```sh
(cd test && ../_build/default/test/config_file_test.exe && ../_build/default/test/rule_config_test.exe && ../_build/default/test/rule_overrides_test.exe && ../_build/default/test/json_diagnostics_test.exe)
opam exec -- dune runtest --root .
make check
make coverage
```

All four focused executables and full `dune runtest` passed.
`make check` passed build, formatting, and six lint adapter tests, then stopped:
`Variable zanuda:version not found ... package zanuda is not installed in this
switch`. The production OCaml lint gate remains unverified; it was not bypassed.
`make coverage` passed, including its instrumented full suite and per-file 90%
gate: overall 96.62%, config_file.ml 99.27%, cli_command.ml 97.28%.
Remaining work is the missing Zanuda gate and fresh Codex review, not native
test or coverage execution.

### 2026-10-22: review handoff

Pushed ede2675 (plan), 67aef39 (normal main merge), and 9b39b2a (contract and
validation record) to the existing PR #29 branch without force. Updated its
description and requested the GitHub Codex integration review:
https://github.com/jderochervlk/rescript-lint/pull/29#issuecomment-6343236165.
Review completion and fresh CI remain pending at handoff. The parent should
resume review handling and the missing lint gate; no merge is authorized here.
