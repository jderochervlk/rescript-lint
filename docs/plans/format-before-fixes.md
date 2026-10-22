# Format ReScript before applying lint fixes

Created: 2026-10-22
Last updated: 2026-10-22
Status: Planned
Issue: None; requested in conversation on [PR #44](https://github.com/jderochervlk/rescript-lint/pull/44)
Feature documentation: [Multiline blank lines](../features/multiline-blank-lines.md)

## Problem and intended outcome

The multiline spacing rule currently needs callers to format source before
running `--fix`. A compact expression can become multiline during formatter
validation, causing fixes to fail with instructions to format and retry. Make
`--fix` run the bundled ReScript formatter automatically before calculating and
applying lint edits, then save the formatted and fixed result in one write.

## Scope and non-goals

- Apply formatting to `.res` and `.resi` files in fix mode, including files with
  no lint findings and files with `blank-lines` disabled. Plain lint mode keeps
  checking the original source without formatting or writing.
- Use the existing pinned ReScript 12.3.1 formatter and its default settings,
  including its newline output. Do not add a formatter dependency, shell
  command, configuration option, or custom newline transformation.
- Preserve the original-input parse/analysis failure guard, rule selection,
  suppression filtering, bounded fix convergence, final formatter validation,
  and single atomic write against the original file snapshot.
- Recompute diagnostics and edits after formatting. Never apply original-source
  offsets to the formatted source. Suppressions are evaluated on each candidate.
- Update the existing PR and its living feature documentation; retain both
  original plans as explicitly historical records.

## Approach and decisions

Keep an initial lint preflight to reject original parse/analysis failures with
locations matching the unchanged file. After successful preflight, format the
source in memory, validate the formatter output, and lint that new source before
applying fixes. Return the formatted candidate even when no lint edits remain.
The existing write boundary compares the final output with the original source,
so already formatted, clean files still avoid a write. Retain the final spacing
compatibility check for edited candidates, but remove obsolete format-first
retry guidance because formatting is now automatic.

Rule-level tests should continue to verify minimal newline edits on the supplied
source independently of the full formatter-and-fixer pipeline. Fixer and CLI
tests will verify formatted output, expansion recovery, idempotence, remaining
diagnostic locations, disabled/suppressed rules, interface files, and failures
without partial writes.

## Implementation steps

- [ ] Commit this plan before implementation.
- [ ] Format in memory before calculating lint edits and update the API contract.
- [ ] Adjust focused regressions and CLI integration expectations, retaining
  existing safety, convergence, and rule-level edit coverage.
- [ ] Update CLI help, README, rule references, and feature documentation.
- [ ] Run focused checks, `make check`, and `git diff --check`.
- [ ] Consolidate this plan into the feature record and update PR #44.

## Validation

Planned checks: focused `fixer_test` and `blank_lines_test` Dune executables,
CLI integration tests, `make check`, and `git diff --check`. No npm packaging
changes are planned. Actual results: no implementation checks run yet.

## Open questions and remaining work

No unresolved behavior decisions. Implementation and validation remain pending.
