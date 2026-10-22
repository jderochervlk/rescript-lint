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
`--fix` inserts the missing empty line. The existing before/after rules for
switches, pipes, externals, and annotated bindings remain intact.

## Design and boundaries

`Blank_lines.requires_separator` checks the final left `Layout_node` source
span at existing adjacent-row boundaries. It reuses the parser locations and
traversal, including complete recursive groups and truncated local declaration
locations, without duplicating AST analysis.

An inner spacing edit can make an enclosing compact declaration multiline.
`Fixer` therefore re-lints each in-memory candidate and applies newly required
edits until no fixable findings remain. Every pass uses the supplied lint
capability, so rule selection and suppression filtering remain authoritative.
No-progress edits or remaining fixable findings after ten batches are errors.
Formatting is checked once after convergence; the existing file writer receives
only the final minimal edits and the original file snapshot.

Formatting can independently expand a source row from one line to several.
When this leaves missing spacing during validation, the fix is rejected without
writing and the diagnostic instructs the caller to format first, then retry
`rescript-lint --fix`. The fixer does not write formatter output or silently
accept formatting conflicts. Compatibility remains scoped to ReScript 12.3.1.

## Validation

Checks performed on 2026-10-22 with the pinned OCaml/ReScript toolchain:

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
