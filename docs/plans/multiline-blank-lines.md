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
