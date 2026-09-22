# Additional syntax rules

These twelve rules use the pinned ReScript 12.3.1 parser and require no compiler
build. They report errors with source ranges and do not offer automatic fixes.
They complement the ten existing rules documented in [RULES.md](RULES.md).

## Activation

`rescript-lint --list-rules` lists every rule and its default activation.
`--enable-rule ID` and `--disable-rule ID` accept one exact ID each and may be
repeated. The last setting for an ID wins. Unknown IDs and missing arguments
are usage errors. Arguments following `--` are always filenames.

```sh
rescript-lint --enable-rule no-empty-function src/Example.res
rescript-lint --enable-rule no-warning-comments --disable-rule no-console src/Example.res
rescript-lint --fix --enable-rule simplify-boolean-expression src/Example.res
rescript-lint --watch --enable-rule max-params src/Example.res
rescript-lint --enable-rule no-empty-function lsp --stdio
```

Selection applies to all explicit inputs, watch reruns, fixes, and LSP buffers.
Disabled rules produce neither diagnostics nor edits. Disabling
`no-unhandled-throws` also skips that rule's source-local contract analysis;
it does not suppress parser or I/O errors. There is no warning severity.

The library exposes `Rule_config`, `Linter.lint_source_with_rules`, and
`Linter.lint_file_with_rules`. Existing `lint_source` and `lint_file` use default
activation. `Policy_rules.check ~limits` accepts custom numeric limits when
embedding the rule pack; the CLI currently uses the defaults below.

## Rule contracts

| Rule | Default | Initial contract |
| --- | --- | --- |
| `no-debugger` | Enabled | Report executable `%debugger` expressions, including nested functions/modules. |
| `no-useless-catch` | Enabled | Report a try/catch whose every unguarded handler immediately rethrows the same caught exception variable or alias. |
| `no-catch-all-exception` | Disabled | Report unguarded wildcard/variable catch-all patterns in try handlers and switch exception arms, except recognized immediate rethrows. |
| `simplify-boolean-expression` | Disabled | Report boolean-literal comparisons, opposite literal if results, neutral logical operands, double negation, and two-arm boolean identity/negation switches. |
| `no-useless-concat` | Disabled | Report explicit `++` expressions joining two ordinary string literals or containing an empty literal operand. |
| `approx-constant` | Disabled | Report float literals within 0.000005 of a supported positive or negative `Math.Constants` value. |
| `no-empty-function` | Disabled | Report literal unit bodies, except bodies explicitly annotated with the `unit` return type. |
| `no-empty-file` | Disabled | Report implementations with no structure items other than attributes. Interfaces are exempt. |
| `no-warning-comments` | Disabled | Report comments containing whole TODO, FIXME, or HACK words, ignoring ASCII case. Includes documentation comments. |
| `max-nesting` | Disabled | Report the first control-flow level beyond four inside each function or top-level expression. |
| `max-params` | Disabled | Report functions with more than five parameters, including labeled and optional parameters. |
| `max-lines-per-function` | Disabled | Report function expressions spanning more than fifty physical source lines. |

## Exception and debugger boundaries

```rescript
// no-debugger
%debugger

// no-useless-catch
let value = try read() catch {
| error => throw(error)
}

// no-catch-all-exception, when enabled
let fallback = try read() catch {
| _ => defaultValue
}
```

The rethrow check recognizes unshadowed `throw`, `raise`, and qualified
`Pervasives` variants. Lexical values, parameters, patterns, modules, recursive
bindings, and functor parameters can shadow them. Unknown opens/includes
conservatively stop recognition. Imported aliases, reconstructed exceptions,
and compound bodies are outside this subset. Guard evaluation and additional
handler work prevent a useless-catch finding. Ordinary switch wildcards are
not exception catch-alls.

This rule remains independent from `no-unhandled-throws`: a handler that
rethrows can satisfy that existing rule while receiving `no-useless-catch`.
Neither rule proves meaningful recovery. Attribute payloads are not executable
code for these checks; a spelling such as `@debugger` is not `%debugger`.

## Expression boundaries

Examples of optional findings:

```rescript
let enabled = ready == true
let active = if ready {true} else {false}
let value = ready && true
let restored = !!ready
let greeting = "hello" ++ " world"
let radiusFactor = 3.14159
```

Use the condition itself, its negation, a single string literal, or the named
constant where appropriate. These are diagnostics, not automatic rewrites.
`read() && false` and `read() || true` are not boolean-simplification findings:
replacing them with literals would discard evaluation. The existing
constant-binary rule can still describe their fixed results without fixing them.
Mixed-literal/dynamic concatenation is not reassociated. Template strings and
character literals are excluded from ordinary string concatenation checks.

Recognized constants are `Math.Constants.e`, `ln2`, `ln10`, `log2e`, `log10e`,
`pi`, `sqrt1_2`, and `sqrt2`, verified against the pinned runtime. Coarse
approximations such as `3.14` stay clean. The rule does not resolve a local
module named Math or infer what a number represents; it is an opt-in
suggestion to use a standard constant, never an automatic replacement.

## Policy boundaries

```rescript
// no-empty-function, when enabled
let noop = () => ()

// Explicit intentional unit callback: clean
let intentional = (): unit => ()

// An empty record is a meaningful value: clean
let emptyRecord = () => {}
```

Empty-file checks ignore source comments and standalone attributes but count
declarations and expressions as meaningful. The linter does not infer generated
files; use an explicit per-file rule override or caller selection for those
sources.

Comment checks use parsed comments and genuine source documentation comments,
not string literals or arbitrary attribute strings. Terms are whole words:
`TODO` matches, `TODO_LIST` and `methodology` do not. Custom terms/contexts and
per-file overrides are configured through the existing project configuration;
generated files require an explicit path-based override rather than automatic
detection.

Nesting counts `if`, switch, try/catch, while, and for constructs. Else-if arms
stay at the same level. Record, module, and JSX layout do not add depth. Functions
start a fresh nesting context; defaults and returned functions are visited
separately. Parameter counting follows the parser's declared function arity, so
one multi-parameter function is not counted repeatedly as nested functions.
The unit placeholder in `() => ...` represents zero parameters. Physical line
limits include comments and blank lines within the function's source span.

Inline suppression comments, numeric configuration, per-file overrides, bounded
semantic inference, and runtime adapters are documented in
[EXTENDED_RULES.md](EXTENDED_RULES.md). The implementation log and grouped
follow-up work are in [RULE_WORK_LOG.md](RULE_WORK_LOG.md).
