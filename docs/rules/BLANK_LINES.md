# Blank Lines and Autofix

`blank-lines` is enabled by default. It requires at least one empty separator
line at supported neighboring declaration/statement boundaries:

- After each external declaration in `.res` and `.resi` files.
- Before annotated value bindings/declarations, including `@get`, `@send`,
  `@deprecated`, and `@react.component`. Stacked annotations stay together
  with their binding. Internal parser attributes are not user annotations.
- After a piped expression statement or a binding whose value is a pipe chain.
  Both single-line and multiline chains qualify. No separators are inserted
  between individual `->` steps.
- Before and after switch expression statements, or the entire binding when
  its value is a switch. A separator is not inserted between `let value =`
  and its `switch` expression.

The traversal supports nested modules/signatures and local statement blocks.
Switch and pipe expressions used as JSX children get separators between their
sibling children, including fragments. This behavior is tested against the
pinned ReScript 12.3.1 formatter, not assumed from JavaScript formatting.

## Formatter-compatible boundaries

There is no padding at the beginning/end of a file, immediately inside opening
or closing braces/tags, or between switch cases merely because a switch exists.
A final switch/pipe in a block therefore does not get an empty line before `}`.
Expressions nested in call arguments, record fields, arrays, conditions, or
other expression positions do not get their own separator. Their internal
statement blocks are still visited. Annotated type/module declarations and
individual members of recursive `let rec ... and ...` groups are outside the
initial annotation rule; each recursive value group is treated as one unit.

These limits are deliberate: this is statement/declaration spacing, not an
attempt to force arbitrary expression whitespace that the formatter removes.
Existing extra blank lines are left untouched. Leading comments stay with the
following declaration; same-line trailing comments stay with the preceding
statement. Strings, raw JavaScript, and annotation payloads remain opaque.

The implementation uses the pinned parser's locations and comment ranges. The
formatter's `print_list` preserves blank lines between structure/signature and
block rows; `print_jsx_children` preserves sibling separation. See the pinned
[`res_printer.ml`](https://github.com/rescript-lang/rescript/blob/679406560d169f1124653ab50795d5077570f078/compiler/syntax/src/res_printer.ml).

## Usage

```sh
rescript-lint src/Example.res src/Api.resi
rescript-lint --fix src/Example.res src/Api.resi
```

Without `--fix`, nothing is written. With it, the linter:

1. Parses and lints each file. Syntax or analysis failures prevent editing that file.
2. Collects byte-range edits from diagnostics, deduplicating identical edits and
   rejecting conflicting or invalid ranges. The spacing rule only inserts newlines.
3. Re-parses/re-lints the candidate and requires that no fixable findings remain.
4. Formats the candidate in memory with ReScript 12.3.1 at its default width,
   then rechecks spacing. A formatter conflict fails without changing the file.
   The formatter's output is not written: only the minimal edits are saved.
5. Replaces the file using an adjacent temporary file and rename, preserving
   permission bits and checking that the disk contents/identity have not changed.

LF/CRLF convention is preserved using the first newline in the file; a missing
final newline is not added. Symlinks, multiply linked files, read-only files,
and nonregular files are not rewritten. Already-clean files are not rewritten.
The changed-file check is best-effort, not a filesystem lock or multi-file
transaction. ACLs, extended attributes, and other filesystem metadata are not
promised to survive replacement; permission-bit checks are tested on POSIX.

Exit codes describe the result after fixes: `0` clean, `1` remaining lint
findings, `2` usage/input/analysis/fix/write failure. Other valid files are still
processed after a failure. Remaining diagnostics use the updated source ranges.
No semantic rule is automatically repaired, suppressed, or disabled.

## Regression contract

Tests assert exact edits, a second fix producing no changes, and a clean spacing
check after official formatting. Fixtures cover comments, annotations, externals,
switches, pipe chains, nested blocks, JSX, `.resi`, Unicode, CRLF, same-line
statements, and untouched expression contexts. Additional tests exercise edit
conflicts, failed validation, file permissions, stale writes, and CLI/npm installs.

Compatibility is currently scoped to the pinned formatter version. Re-run these
tests when upgrading it; a project's different installed formatter version is
not automatically detected or guaranteed compatible.
