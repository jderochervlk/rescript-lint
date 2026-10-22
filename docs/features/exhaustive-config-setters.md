# Exhaustive configuration setters

Created: 2026-10-22
Last updated: 2026-10-22
Status: Implemented
Issue: https://github.com/jderochervlk/rescript-lint/issues/18

## Purpose and supported behavior

PR #29 makes JSON option selection explicit for all 21 project-option
properties. Each branch reuses the existing primitive decoder and updates only
the named record field. The wildcard rejects unknown properties; it never
selects a valid setter. A private CLI option variant makes the mapping for
`--config`, `--project`, `--jsx-runtime`, `--test-framework`, and
`--throws-runtime` exhaustive.

This is internal hardening, not a fix for previously accepted unknown keys.
No new options or configuration schema are introduced.

## Usage and compatibility

Existing configuration files and CLI flags remain unchanged. Adapter names
remain exact and case-sensitive: `react-dom`, `rescript-vitest-3`, and
`rescript-12.3.1`. JSON null resets only the corresponding nullable adapter.
Nonnegative limits and the minimum deep-equality threshold of 2 retain their
existing decoders and error text.

Relative JSON paths use the configuration file's parent directory; CLI project
paths use `.` (the working directory). Absolute paths remain absolute. Lists
retain input ordering. Configuration and CLI settings are applied in argument
order, so later settings win; option origins and file ordering are unchanged.
Duplicate keys are rejected before decoding, and unknown and malformed values
retain existing errors. Rules, overrides, and `$schema` retain their existing
special handling.

## Design and boundaries

See `lib/config/config_file.ml` and `lib/cli/cli_command.ml`. The long JSON
property match intentionally keeps each key adjacent to its field update,
instead of adding a schema framework or another dispatch layer.

`test/config/config_file_test.ml` compares complete option records for each
supported property against default and populated initial settings. It also
covers adapter null resets, exact malformed/duplicate/unknown errors, CLI
selection and missing values, origins, both precedence orders, path bases, and
file ordering. Existing rule configuration, override, and JSON diagnostic tests
remain relevant and unchanged.

## Validation and limitations

Static review found no missing setter or semantic change requiring a new source
patch. On 2026-10-22, initial checks could not find Dune. A retry using an existing
dependency switch read-only and the restored pinned submodule passed all four
focused tests, full `dune runtest`, and `make coverage`. Coverage was 96.62%
overall, 99.27% for config_file.ml, and 97.28% for cli_command.ml.

The first `make check` retry stopped because Zanuda was not installed. After the
parent provisioned pinned Zanuda 2.1.0 centrally, exact `make check` passed:
build, formatting, six lint adapter tests, OCaml lint (487 sources, zero
findings), and the full native suite. This worker used the existing dependency
switch read-only and committed no vendor changes.

Validation environment and commands:

```sh
export OPAMSWITCH=/home/josh/Dev/rescript-linter DUNE_ROOT="$PWD"
opam exec -- dune build --root . test/config_file_test.exe test/rule_config_test.exe test/rule_overrides_test.exe test/json_diagnostics_test.exe
(cd test && ../_build/default/test/config_file_test.exe && ../_build/default/test/rule_config_test.exe && ../_build/default/test/rule_overrides_test.exe && ../_build/default/test/json_diagnostics_test.exe)
opam exec -- dune runtest --root .
make coverage
make check
```

GitHub Codex reviewed 1817279 and reported no major issues:
https://github.com/jderochervlk/rescript-lint/pull/29#issuecomment-6343286659.
The final documentation consolidation requires review of its new head.
Historical PR CI is not evidence for the new head. The old Windows npm job
failed with EPERM in a temporary-path package test; packaging is unchanged and
local npm packaging checks were not run. No merge or auto-merge is authorized.

## Historical planning record

### Verify exhaustive configuration setters

Plan created: 2026-10-22
Plan last updated: 2026-10-22

Original plan committed as ede2675, preserved verbatim below. This is historical
intent, not an active checklist. Original implementation c21323c predates it;
this does not retroactively claim the original work followed PR #36's lifecycle.

```markdown
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
```

### Dated decisions and progress: 2026-10-22

- Inspected PR author jderochervlk, prior Codex review, comments, and branch.
  No ownership conflict or source defect justified new implementation. Merged
  latest main (59850f4) normally as 67aef39, preserving shared history.
- Original directory-level test plan changed after inspecting `test/dune`:
  `include_subdirs unqualified` places executables at the test root. Initial
  focused build, `make check`, and `make coverage` all stopped with
  `[ERROR] Command not found 'dune'`; no native result was claimed then.
- Parent identified the existing dependency switch. Restored pinned submodule
  679406560d169f1124653ab50795d5077570f078 inside this isolated workspace.
  Initial clone timed out and retry could not find the current revision;
  recovered via shallow fetch of the exact gitlink and detached checkout.
- Focused build succeeded. Direct execution from repository root failed the
  rule-config fixture checks because they expect test cwd; corrected to the
  commands above. Four focused tests, full suite, and coverage then passed.
- The first provisioned-tool `make check` passed build/format and adapter tests,
  but lacked Zanuda. Parent subsequently installed pinned 2.1.0 centrally;
  final exact `make check` passed with zero lint findings. No gates weakened.
- Pushed ede2675 (plan), 67aef39 (main merge), 9b39b2a (contract/results), and
  1817279 (review handoff) without force to existing PR #29. Requested actual
  GitHub Codex review; receipt on 1817279 reported no major issues. Consolidated
  the completed plan here while retaining original creation date and intent.
