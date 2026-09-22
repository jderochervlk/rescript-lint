# Additional Opt-in Policies

These 18 rules are disabled by default. They share configuration, per-file
overrides, audited suppressions, CLI/fix/watch and LSP integration. None produces
edits. The catalog now has 123 rules, with the same twelve defaults.

| Rule | Bounded contract |
| --- | --- |
| `no-optional-some` | Direct optional labeled arguments written `~label=?Some(value)`, when the constructor resolves to the builtin option constructor. Leave `None`, arbitrary options, mandatory arguments and shadowed constructors alone. |
| `preferred-type-syntax` | Prefer builtin `dict<a>` for known standard `Dict.t<a>`, including standard aliases/opens and `.resi` annotations. Project/local types named `Dict.t` are excluded. No automatic rewrite. |
| `no-identity-operation` | Integer `x + 0`, `0 + x`, `x - 0`, `x * 1`, `1 * x`, and `x / 1`, when both operand types are known integers. Floats and unknown operands are excluded. |
| `no-erasing-operation` | Integer multiplication by literal zero on either side. Guidance preserves operand effects; no fix removes evaluations. |
| `no-modulo-one` | Integer `%` and resolved standard `mod` with divisor literal 1 or -1. Shadowed named functions and floats are excluded. |
| `no-obj-external` | External declarations carrying `@obj`/legacy `@bs.obj`, in implementations and interfaces. This is an FFI policy, not a correctness finding. |
| `no-mutable-record-field` | Each `mutable` record field declaration, including signatures. |
| `no-record-mutation` | Record-field assignments, including reference-cell field assignments. No claim to cover every form of mutation. |
| `no-while` | Every syntactic while loop. Intentional imperative code can leave this policy disabled or use audited suppression. |
| `no-for` | Every syntactic counting loop, in either direction. Collection callbacks are not loops for this policy. |
| `no-empty-loop` | While/for bodies consisting solely of unit, optionally type-constrained. Comments do not supply executable behavior. Effectful sequences are excluded. |
| `no-negated-condition` | If/ternary expressions with both branches and a direct syntactic `!` condition. Named `not` calls and if-without-else are excluded. |
| `no-nested-ternary` | A ternary immediately containing another ternary in its condition or either arm, through type constraints. Ordinary nested ifs are excluded. |
| `prefer-if` | Two-arm boolean switches with distinct true/false patterns and no guards. It may overlap `simplify-boolean-expression` when both results are boolean literals. |
| `no-single-case-switch` | A single unguarded wildcard/variable arm. Refutable constructor patterns and guards are excluded. |
| `no-unnecessary-template` | Complete untagged, interpolation-free template literals, including empty/multiline templates. Interpolation fragments, tagged templates, JSON templates and ordinary strings are excluded. |
| `max-lines` | Physical lines in `.res`/`.resi`, including comments and blank lines. An ending newline does not add an extra line; empty files have zero lines. |
| `max-switch-cases` | Number of syntactic switch arms. An or-pattern counts once; guards still count. Catch handlers are excluded. |

`maxLines` defaults to 300 and `maxSwitchCases` to 10. Both accept nonnegative
integers, including zero. As with existing limits, configuring a threshold does
not enable its rule. Use per-file overrides for generated files and intentional
exceptions.

Source type inference is bounded. Integer checks do not infer unknown external
return types; dictionary recognition distinguishes standard type provenance from
project declarations with the same spelling. These policies do not require a
project build, but a configured project contributes public signatures.

Compiler-checked invalid/valid examples are in [RULE_EXAMPLES.md](RULE_EXAMPLES.md).
Unit tests additionally cover parser boundaries, shadows, signatures, Unicode
ranges, thresholds, metadata reporting, and policy overlap.
