# Blank Lines and Autofix

`blank-lines` is enabled by default. It requires at least one empty separator
line at supported neighboring declaration/statement boundaries:

- After any statement or declaration whose source span covers multiple lines,
  including functions, modules, types, conditionals, loops, ordinary calls, and
  value bindings. The complete declaration counts, including annotations or
  multiline literal values. This does not add a corresponding separator before
  the multiline declaration.
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
Multiline JSX children, as well as switch and pipe expressions used as JSX
children, get separators between their sibling children, including fragments.
For example, `--fix` adds the blank line after this multiline function:

```rescript
let increment = value => {
  let next = value + 1
  next
}

let result = increment(1)
```

This behavior is tested against the pinned ReScript 12.3.1 formatter, not
assumed from JavaScript formatting.

## Formatter-compatible boundaries

There is no padding at the beginning/end of a file, immediately inside opening
or closing braces/tags, or between switch cases merely because a switch exists.
A final multiline statement, switch, or pipe in a block therefore does not get
an empty line before `}`.
Expressions nested in call arguments, record fields, arrays, conditions, or
other expression positions do not get their own separator. Their internal
statement blocks are still visited. Annotated type/module declarations and
individual members of recursive `let rec ... and ...` groups are outside the
initial annotation-before rule; multiline type/module declarations still get
separation after them. Each recursive value group is treated as one unit, even
when its individual bindings occupy separate lines.

These limits are deliberate: this is statement/declaration spacing, not an
attempt to force arbitrary expression whitespace that the formatter removes.
The spacing rule leaves existing extra blank lines untouched. Leading comments
stay with the following declaration; same-line trailing comments stay with the
preceding statement. Strings, raw JavaScript, and annotation payloads remain opaque:
their contents are not edited, even when a containing declaration requires
separation afterward.

The implementation uses the pinned parser's locations and comment ranges. The
formatter's `print_list` preserves blank lines between structure/signature and
block rows; `print_jsx_children` preserves sibling separation. See the pinned
[`res_printer.ml`](https://github.com/rescript-lang/rescript/blob/679406560d169f1124653ab50795d5077570f078/compiler/syntax/src/res_printer.ml).

## Usage

```sh
rescript-lint src/Example.res src/Api.resi
rescript-lint --fix src/Example.res src/Api.resi
```

Without `--fix`, the linter checks the supplied source without formatting or
writing. With it, the linter:

1. Parses and lints the original file to reject syntax or analysis failures
   before changing it. Errors at this stage refer to the original source.
2. Formats the file in memory with the bundled ReScript 12.3.1 formatter at its
   default width, then validates and lints the formatted source. Original
   diagnostic locations and edits are discarded and recomputed.
3. Collects byte-range edits from the new diagnostics, deduplicating identical
   edits and rejecting conflicting or invalid ranges. The spacing rule only
   inserts newlines, after the formatter has established the source layout.
4. Re-parses/re-lints each edited candidate and applies remaining fixes in memory.
   Every pass respects rule selection and suppressions; no-progress edits or
   failure to converge within ten batches prevent writing. The final candidate
   must have no fixable findings. Edited candidates also pass a final formatter
   compatibility check; a conflict fails without changing the file.
5. Saves the formatted and fixed result in a single replacement using an adjacent
   temporary file and rename, preserving permission bits and checking that the
   disk contents/identity have not changed.

Formatting can expand a compact expression or collapse a multiline expression.
Fix mode calculates spacing requirements from that formatted layout, so running
the formatter separately first is unnecessary. Formatting runs even when there
are no lint findings, only nonfixable findings, or `blank-lines` is disabled.
Suppression comments are reevaluated on the formatted text; directives targeting
a physical line follow their position after formatting.

The saved output follows the formatter's newline behavior, including LF line
breaks and a final newline. The spacing rule itself preserves the supplied line
ending convention when generating edits. Symlinks, multiply linked files,
read-only files, and nonregular files are not rewritten. Files whose formatted
and fixed output already matches their contents are not rewritten.
The changed-file check is best-effort, not a filesystem lock or multi-file
transaction. ACLs, extended attributes, and other filesystem metadata are not
promised to survive replacement; permission-bit checks are tested on POSIX.

Exit codes describe the result after fixes: `0` clean, `1` remaining lint
findings, `2` usage/input/analysis/fix/write failure. Other valid files are still
processed after a failure. Remaining diagnostics use the updated source ranges.
No semantic rule is automatically repaired, suppressed, or disabled.

## Regression contract

Rule tests assert exact newline edits on the supplied source. Fixer tests assert
formatted output, a second fix producing no changes, and a clean spacing check
after official formatting. Fixtures cover comments, annotations, externals,
switches, pipe chains, multiline declarations/expressions, recursive groups,
nested blocks, JSX, `.resi`, Unicode, CRLF, same-line statements, and untouched
expression contexts. Additional tests exercise formatter expansion and collapse,
formatting-only changes, final diagnostic locations, disabled/suppressed rules,
edit conflicts, failed validation, file permissions, stale writes, and CLI/npm
installs.

Compatibility is currently scoped to the pinned formatter version. Re-run these
tests when upgrading it; a project's different installed formatter version is
not automatically detected or guaranteed compatible.

The [multiline spacing feature record](../features/multiline-blank-lines.md)
documents the implementation decisions, validation, and original plan.
