# Blank lines after multiline statements and declarations

Created: 2026-10-22
Last updated: 2026-10-22
Status: Implemented
Issue: None; requested in conversation

## Purpose and supported behavior

The default `blank-lines` rule requires an empty separator after a multiline
statement or declaration when another supported row follows. This covers
functions, modules, types, conditionals, loops, ordinary calls, complete
recursive binding groups, interface declarations, and JSX siblings. Complete
source spans count, including annotations and multiline literal values.

Existing category-specific spacing requirements still apply. The rule does not
introduce generic spacing before multiline rows or padding at file/block edges.
Nested argument, record, array, and condition expressions remain outside the
row-spacing contract; their internal statement blocks are still visited.

See [Blank Lines and Autofix](../rules/BLANK_LINES.md) for the authoritative
contract, comment association, line endings, and file-writing guarantees.

## Usage

`blank-lines` remains enabled by default, with no new configuration setting.

```sh
rescript-lint src/Example.res src/Api.resi
rescript-lint --fix src/Example.res src/Api.resi
```

A multiline function followed immediately by another declaration is diagnosed;
`--fix` formats the source with the bundled ReScript formatter before inserting
the missing empty line. It saves formatting changes even when no lint fixes are
needed or `blank-lines` is disabled. The existing before/after rules for switches,
pipes, externals, and annotated bindings remain intact.

## Design and boundaries

`Blank_lines.requires_separator` checks the final left `Layout_node` source
span at existing adjacent-row boundaries. It reuses the parser locations and
traversal, including complete recursive groups and truncated local declaration
locations, without duplicating AST analysis.

`Fixer` validates the original source before formatting it in memory, preserving
original parse/analysis error locations when the file cannot be processed. It
then validates and lints the formatter output. Spacing requirements, edit offsets,
and suppression decisions are recalculated from that formatted layout; formatting
can expand a compact row or collapse a multiline one. The final diagnostics
refer to the resulting source.

After formatting, the fixer re-lints each edited candidate and applies newly
required edits until no fixable findings remain. Every pass uses the supplied
lint capability, so rule selection and suppression filtering remain authoritative.
No-progress edits or remaining fixable findings after ten batches are errors.
Edited candidates pass a final formatter compatibility check. Formatting,
validation, and edit passes remain in memory; the existing file writer receives
the final formatted and fixed text and the original file snapshot for one atomic
replacement. A failure prevents writing, and identical final contents avoid a
write.

Fix mode accepts the formatter's newline output, including LF line breaks and a
final newline. Line-scoped suppressions follow their positions after formatting.
Plain lint mode checks the supplied source without formatting or writing.
Compatibility remains scoped to the bundled ReScript 12.3.1 formatter and its
default settings; no separate project formatter is invoked.

## Validation

### Formatting before fixes

Checks performed on 2026-10-22 after adding automatic formatting:

- `opam exec -- dune exec test/blank_lines_test.exe`: passed exact source-span
  edit, idempotence, and independent official-formatter checks.
- `opam exec -- dune exec test/fixer_test.exe`: passed callback ordering,
  expansion/collapse, formatting-only output, disabled/suppressed rules, final
  diagnostic positions, interfaces, newline output, convergence, and failure
  regressions.
- `make format`: passed.
- `make check`: passed build, formatting, OCaml lint (487 sources, zero findings),
  and the complete test suite, including the new CLI integration cases.
- `git diff --check`: passed.

The local run used the root-container adjustments described below. A normal-root
`opam exec -- dune build @all @check @fmt` prepared generated artifacts before
the capability-limited full gate. Repository gates and assertions were unchanged.
The npm package documentation was updated; packaging code was unchanged.

### Initial multiline implementation

Checks performed on 2026-10-22 for the initial implementation, before formatting
was added to fix mode, with the pinned OCaml/ReScript toolchain:

- `opam exec -- dune exec test/blank_lines_test.exe`: passed exact-output,
  idempotence, and formatter-stability regressions.
- `opam exec -- dune exec test/fixer_test.exe`: passed focused convergence,
  suppression, and formatter-expansion regressions. The final call-order and
  pass-limit additions also passed in the complete test suite.
- `make format`: passed.
- `make check`: passed build, formatting, OCaml lint (487 sources, zero findings),
  and the complete test suite, including the CLI regression.
- `git diff --check`: passed.

The local root container required `OPAMROOTISOK=1` and
`setpriv --bounding-set=-dac_override,-dac_read_search -- make check` so Opam's
root warning did not affect strict lint output and unreadable-directory tests
exercised filesystem permissions. Generated test binaries also needed their
execute bits restored immediately before the run. These were environment-only
adjustments; test assertions and repository gates remain intact.

The new cases exercise multiline functions, conditionals, loops, calls, blocks,
modules, types, interfaces, recursive groups, constraints, annotations, literal
content, comments, JSX, CRLF, excluded expression positions, nested cascades,
suppressed inner edits, no-progress edits, the convergence limit, and formatter
failure/recovery. A CLI regression checks the diagnostic and fixed file.

## Historical planning record

### Original implementation plan

Plan created: 2026-10-22
Plan last updated: 2026-10-22

The following is the original plan committed before implementation. Its status
and checkboxes describe historical intent, not the current supported behavior.

```markdown
# Blank lines after multiline statements and declarations

Created: 2026-10-22
Last updated: 2026-10-22
Status: Planned
Issue: None; requested in conversation
Feature documentation: Pending

## Problem and intended outcome

The default `blank-lines` rule fixes selected expression kinds but does not
separate ordinary multiline functions, modules, conditionals, calls, and other
declarations from the following statement. Extend the existing rule so every
supported multiline statement/declaration row requires an empty line after it
when a neighboring row follows.

## Scope and non-goals

- Cover implementation and interface declarations, nested/local blocks, complete
  recursive binding groups, and existing JSX sibling boundaries.
- Use the complete source span of a layout row, including multiline annotations
  or literal values when they belong to that row. Literal contents remain opaque.
- Add separation after multiline rows, without introducing a corresponding
  before rule. Preserve existing switches, pipes, externals, and annotation rules.
- Preserve comment attachment, line endings, existing blank lines, and the lack
  of padding at file/block edges. Do not separate recursive group members or
  arbitrary argument, array, record, or condition expressions.
- Keep this in the existing `blank-lines` rule and `--fix` path. Do not introduce
  a new configuration option, dependency, formatter, or semantic rewrite.

## Approach and decisions

Reuse `Layout_node` locations and the existing adjacent-row traversal. Check
the final left row's start/end source line numbers in the spacing rule, after
the row's complete or block-local truncated location has been calculated.
This keeps rule detection in the rule and avoids another AST traversal.

Retain strict formatter compatibility validation and minimal newline-only edits.
Formatting can introduce multiline rows that were single-line in the input.
When that leaves missing spacing, fail without writing and give accurate
format-first guidance; do not silently waive validation or write the formatter's
output. Test this boundary and the successful format-then-fix workflow.

## Implementation steps

- [ ] Commit this plan before implementation.
- [ ] Extend the adjacent-row spacing predicate and update formatter-conflict
  guidance without changing the validation guarantee.
- [ ] Add exact-output regressions for multiline row kinds and exclusions,
  recursive groups, comments, JSX, interfaces, and formatter compatibility.
- [ ] Update affected integration expectations, preserving assertions unrelated
  to the newly required spacing.
- [ ] Update the rule reference and promote this plan to living feature
  documentation with its original planning record preserved.
- [ ] Run the required checks, review the final diff, and open one ordinary PR.

## Validation

Planned checks:

- Focused `blank_lines_test` and `fixer_test` Dune executables: exact edits,
  idempotence, formatter stability, intentional exclusions, and failure without
  writes when formatting introduces additional spacing requirements.
- `make check`: build, formatting, OCaml lint, and the complete test suite.
- `git diff --check` and review of all changed files before publication.

Actual results: No implementation checks have run yet. The environment initially
lacks Opam and the OCaml toolchain; an isolated local setup is in progress.

## Open questions and remaining work

No unresolved policy decisions. Implementation and validation remain pending.
```

### 2026-10-22: Cascading fixes

Inserting a separator inside a one-line function makes its enclosing row
multiline, which can require another separator. Re-lint and apply filtered edits
in memory until no fixable findings remain, with a ten-pass convergence guard;
validate formatting once afterward and retain the single final file write.
Keep this in `Fixer` so disabled rules and inline suppressions apply on every
pass. Predicting future multiline diagnostics inside the spacing rule would
incorrectly expand ancestors of suppressed edits. Add nested-cascade and
suppression regressions while retaining nonconvergence failure checks.

### Format ReScript before applying lint fixes

Plan created: 2026-10-22
Plan last updated: 2026-10-22

The user requested automatic formatting as part of `--fix`. This later plan
supersedes the earlier requirement to format separately and the earlier promise
to save only newline insertions. Its original committed contents follow.

```markdown
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
```
