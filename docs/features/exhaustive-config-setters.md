# Exhaustive configuration setters

Created: 2026-10-22
Last updated: 2026-10-22
Status: Partially implemented
Issue: https://github.com/jderochervlk/rescript-lint/issues/18
Remaining work: [Verification plan](../plans/exhaustive-config-setters.md)

## Purpose and supported behavior

PR #29 makes JSON option selection explicit for all 21 project-option
properties. Each branch reuses the existing primitive decoder and updates only
the named record field. The wildcard rejects unknown properties; it never
selects a valid setter. A private CLI option variant makes the mapping for
`--config`, `--project`, `--jsx-runtime`, `--test-framework`, and
`--throws-runtime` exhaustive.

This is internal hardening, not a fix for previously accepted unknown keys.
No new options or configuration schema are introduced. The implementation is
present; fresh native validation and review remain outstanding.

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

`make check` passed build, formatting, and six lint adapter tests, then stopped
because Zanuda is not installed in that switch. The OCaml lint gate remains
unverified. No tools were installed and no vendor changes were committed.

The active plan records exact commands, historical evidence, and remaining
validation/review work. Historical PR CI is not evidence for the new head.

## Historical planning record

The original follow-up plan was created and committed on 2026-10-22 as ede2675,
before any new implementation. Its original problem, scope, approach, intended
steps, validation criteria, and open questions remain in the cross-linked active
plan in the final tree; dated progress is appended separately. The original
implementation c21323c predates this plan. This record does not retroactively
claim that the original implementation followed the later PR #36 lifecycle.
