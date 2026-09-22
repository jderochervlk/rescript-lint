# Rule Candidate Plan

Research snapshot: 2026-09-20.

Implementation update, 2026-09-21: all 99 candidate rule IDs below now have
bounded implementations, alongside the six earlier rules (105 total). The
classification table remains the original research taxonomy, not an outstanding
task list. See [EXTENDED_RULES.md](EXTENDED_RULES.md) and
[RULE_OVERNIGHT_LOG.md](RULE_OVERNIGHT_LOG.md) for shipped subsets, prerequisites,
precision limits and verification. Delegate/Reject entries remain excluded.

The subsequent [policy expansion](POLICY_EXPANSION.md) adds 18 opt-in rules,
bringing the current catalog to 123. It also completes configuration inspection,
the shipped schema, type-reference restrictions and policy guidance described in
[CONFIGURATION.md](CONFIGURATION.md).

Additional prior art: [ReScript PR #8351 review](PR_8351_REVIEW.md) compares
its implemented lint/rewrite policies with our current rules and records missing
coverage, adoption recommendations, and prototype behaviors to change. Those
recommendations are separate from the implemented catalog below.

This document records the rule-selection research that informed the shipped
catalog. It compares Oxlint's complete rule catalog with OCaml linters and Rust
Clippy, then separates ideas that transfer to ReScript from rules that depend on
another language's syntax, runtime, package manager, or type system.

Invalid and valid ReScript examples for every proposed rule are collected in
[RULE_EXAMPLES.md](RULE_EXAMPLES.md).

The goal is not rule-count parity. A ReScript rule should identify a real
ReScript bug, performance trap, or maintainability problem with a contract that
can be tested against ReScript source. Rules already enforced well by the
compiler or formatter should stay there.

## Status vocabulary

| Status | Meaning |
| --- | --- |
| **Implement** | A useful ReScript rule with a sufficiently clear contract. |
| **Typed** | Useful, but it needs resolved symbols/types or compiler artifacts to avoid name-based guesses. |
| **Project** | Useful, but it needs a project/module graph rather than one source file. |
| **Adapter** | Useful only when a particular JSX runtime, test framework, or library is configured. |
| **Delegate** | The ReScript compiler, formatter, or existing analyzer already owns it better. |
| **Reject** | The underlying construct does not exist in ReScript or the policy is a poor fit. |

## Diagnostic and suppression policy

Rule configuration is binary: a rule is enabled or disabled. There is no
warning severity and no way to downgrade an enabled rule. Every finding from an
enabled rule is an error and produces the lint-failure exit status. Rules that
are too subjective or noisy for that contract must remain disabled by default
until their precision justifies error-level enforcement.

Inline suppression comments are implemented as part of the rule engine. The
supported forms are:

```rescript
// rescript-lint-disable-line no-console -- required by a diagnostic bridge
Console.log(value)

// rescript-lint-disable-next-line no-console -- required by a diagnostic bridge
Console.log(value)

// rescript-lint-disable no-console -- generated compatibility section
Console.log(firstValue)
Console.log(secondValue)
// rescript-lint-enable no-console
```

The suppression contract has these properties:

- Every directive names one or more exact rule IDs. An all-rules suppression is
  not part of the initial design.
- `disable-line` applies to findings whose primary range starts on that line;
  `disable-next-line` applies to the next syntax-bearing line; paired
  `disable`/`enable` comments define an explicit source region.
- A region suppression may intentionally last to end of file, which also
  provides file-wide suppression without a separate mechanism.
- The `-- reason` text is supported and preserved for auditability. Requiring
  reasons in CI is a future configuration capability.
- Unknown rule IDs, malformed directives, unmatched `enable` comments, and
  unused suppressions are themselves errors so stale or misspelled exceptions
  do not silently accumulate.
- Suppressions apply only to lint-rule findings. Read, parse, write, fix, and
  semantic-analysis failures cannot be suppressed from source comments.
- Suppressed findings are omitted from reporters and are not changed by
  `--fix`.

## Compiler verification

The examples were audited on 2026-09-20 with ReScript 12.3.1. Each invalid and
valid half for the 99 remaining candidates was compiled as its own module, for
198 compiler-checked fixtures in total. JSX fixtures used
`@rescript/react` 0.15.0, test fixtures used `rescript-vitest` 3.0.1, and the
project-policy fixtures were additionally built in the multi-file layouts their
comments describe. A shared typed fixture supplies only the surrounding values
that the short excerpts omit.

This audit removed rules whose invalid examples are already rejected by the
compiler: `aria-props`, `aria-proptypes`, `react/no-unknown-property`,
`test/valid-describe-callback`, `test/valid-expect`, `no-cyclic-modules`, and
`no-self-module-reference`. It also deferred
`test/no-interpolation-in-snapshots` because the selected ReScript Vitest
binding has no inline-snapshot-text API to inspect. Compiler warnings are not
treated as lint severities; examples that deliberately exercise deprecation or
an unnecessary `rec` still compile successfully under the default compiler
policy.

Compilation establishes that both sides are legal ReScript programs. It does
not by itself prove that a diagnostic is useful or that an autofix preserves
behavior; those remain rule acceptance-test requirements.

## Current baseline

The linter already implements these rule families:

- `no-console`
- `no-object-magic`
- `no-unsafe`
- `react/rules-of-hooks`
- `no-unhandled-throws` (source-local subset)
- `blank-lines`
- `no-constant-condition`
- `no-constant-binary-expression`
- `no-duplicate-condition`
- `no-identical-branches`

Their current contracts and limitations remain in [RULES.md](RULES.md). New
rules should use the same source-range, diagnostic-ordering, parse-failure, and
fix-validation behavior.

The 2026-09-20 expansion implements all twelve remaining syntax candidates in
the first table below. `no-debugger` and `no-useless-catch` are enabled by
default; the other ten remain opt-in. See [SYNTAX_RULES.md](SYNTAX_RULES.md) for
the precise initial subsets, fixed CLI policy defaults, and library limit
configuration. `--list-rules`, `--enable-rule`, and `--disable-rule` are now
available in every execution mode. Full project configuration and inline
suppression/auditing are implemented. [RULE_WORK_LOG.md](RULE_WORK_LOG.md)
records the parallel implementation, grouped fixes, and verification.
`--list-rules` shows built-in defaults. Use `--inspect-config FILE` for the
effective per-file configuration and its origins; the configuration-observability
milestone in [PLAN.md](PLAN.md) is implemented.

## Original delivery order and candidate contracts

The tables below preserve the original research targets. For the shipped,
bounded behavior of each implemented subset, use [EXTENDED_RULES.md](EXTENDED_RULES.md)
and [SYNTAX_RULES.md](SYNTAX_RULES.md).

### 1. High-confidence syntax rules

These rules are implemented against the parsed source tree. They were the first
rule wave because they did not depend on the project index.

| Proposed rule | Initial activation | Contract | Inspiration |
| --- | --- | --- | --- |
| `no-constant-condition` | Enabled | Report `if`, `switch` guards, and loop conditions that are statically constant after side-effect-safe folding. Do not erase evaluated effects. | Oxlint `no-constant-condition`; Clippy `overly_complex_bool_expr` |
| `no-constant-binary-expression` | Enabled | Report comparisons and boolean operators whose result is fixed by literals or safe local constant folding, while preserving evaluation effects. Leave type-sensitive same-expression cases to `no-self-compare`. | Oxlint `no-constant-binary-expression`, `const-comparisons`, `erasing-op`; Clippy `identity_op`, `erasing_op` |
| `no-duplicate-condition` | Enabled | Report repeated conditions in one `if`/`else if` chain and duplicate switch guards. | Oxlint `no-dupe-else-if`; Clippy `ifs_same_cond` |
| `no-identical-branches` | Enabled | Report adjacent `if` branches or switch arms with structurally identical results after excluding comments and source trivia. | Clippy `if_same_then_else`, `match_same_arms`; Oxlint `branches-sharing-code` |
| `simplify-boolean-expression` | Disabled | Cover `x == true`, `if x {true} else {false}`, neutral `&&`/`\|\|` operands, double negation, and boolean switches. Only fix transformations that preserve evaluation. | Zanuda `if_bool`/`match_bool`; Camelot boolean checks; Clippy `bool_comparison`, `needless_bool`, `nonminimal_bool` |
| `no-useless-catch` | Enabled | Report handlers that only rethrow the unchanged caught exception. Do not combine this with the stricter handling policy of `no-unhandled-throws`. | Oxlint `no-useless-catch` |
| `no-catch-all-exception` | Disabled | Report unguarded wildcard or variable catch-all exception patterns unless they immediately rethrow or are explicitly suppressed. | Zanuda `exc_error_swallowing`; Olint `try-catchall` |
| `no-empty-function` | Disabled | Report function bodies with no meaningful expression. Allow explicit unit-returning callbacks through configuration or an annotation. | Oxlint `no-empty-function` |
| `no-empty-file` | Disabled | Report a source file with no declarations, excluding generated or declaration-only files configured by the project. | Oxlint `no-empty-file` |
| `no-debugger` | Enabled | Report ReScript debugger expressions/attributes supported by the pinned compiler. | Oxlint `no-debugger` |
| `approx-constant` | Disabled | Report numeric literals that closely reproduce standard constants such as pi or e when a stable ReScript standard-library constant exists. | Oxlint and Clippy `approx-constant` |
| `no-useless-concat` | Disabled | Report concatenation of adjacent literals and empty strings. Avoid reassociation of dynamic string expressions. | Oxlint `no-useless-concat`; Clippy string lints |
| `no-warning-comments` | Disabled | Configurable `TODO`/`FIXME`/`HACK` policy for comments, with terms and allowed contexts supplied by configuration. | Oxlint `no-warning-comments` |
| `max-nesting` | Disabled | Configurable maximum nesting for executable control flow; do not count module/record/JSX layout as control-flow nesting. | Clippy `excessive_nesting`; Oxlint `max-depth`; Zanuda nested-if rule |
| `max-params` | Disabled | Configurable function parameter limit, counting labeled and optional parameters once across the parser's nested function nodes. | Oxlint `max-params`; Clippy `too_many_arguments` |
| `max-lines-per-function` | Disabled | Configurable physical-line limit with generated code and declarations excluded. | Oxlint `max-lines-per-function`; Clippy `too_many_lines` |

Before enabling fixes, add acceptance tests for comments between transformed
nodes, Unicode ranges, nested functions, parser recovery behavior, and
formatter stability. Complexity/size limits should remain opt-in policy rules,
not default claims about correctness.

### 2. Typed and API-aware rules

These are good rules, but implementing them with bare identifier matching would
repeat the known alias/open/shadow limitations of the initial banned-API rules.
The implementation uses bounded project-aware symbol and type metadata rather
than bare identifier matching. Its unknown-analysis boundaries remain part of
each rule's contract.

| Proposed rule | Contract | Required analysis | Inspiration |
| --- | --- | --- | --- |
| `no-self-compare` | Report a stable expression compared with itself. Exclude calls and mutable reads. Handle float operands explicitly because `value != value` can be an intentional NaN test, for which a named predicate is clearer. | Operand types, resolved bindings, and effect classification | Oxlint `no-self-compare`; Clippy `eq_op` |
| `no-unintended-shallow-equality` | Report when `===`/`!==` compares arrays, records, objects, tuples, payload variants, or regex values and value equality is likely intended. Allow an explicit identity-comparison annotation. | Operand types | Zanuda `physical_equality` |
| `no-expensive-deep-equality` | Report when `==`/`!=` invokes runtime deep comparison for a type or expression above a configurable risk threshold. | Operand types and ReScript equality lowering | ReScript equality documentation; performance-oriented Clippy lints |
| `no-float-equality` | When enabled, report exact equality of computed floats. Exempt literals, explicit sentinels, and contexts configured as exact-domain code. Suggestions must use a scale-aware tolerance, not a naive fixed epsilon. | Operand types and expression classification | Clippy `float_cmp`, `float_equality_without_abs` |
| `prefer-pattern-check` | Optionally prefer a switch or predicate over deep equality used only to test a list/option/variant shape. Do not report primitive or payload-free comparisons that the compiler lowers efficiently. | Operand and constructor types | Zanuda `use_match_instead_of_equality` |
| `prefer-empty-check` | Replace `List.length(xs) == 0`, `> 0`, and equivalent array/string length comparisons with the canonical empty check for the resolved collection API. | Symbol identity and operand type | Zanuda/Olint `list-length-compare`; Clippy `comparison_to_empty`, `len_zero` |
| `no-partial-function` | Extend the versioned unsafe inventory to partial APIs that throw or assume non-empty input, with safe alternatives in the diagnostic. Keep invalid-value APIs in `no-unsafe` and throwing APIs aligned with `no-unhandled-throws`. | Symbol identity and versioned API inventory | Olint `partial-function`/`list-nth`; Clippy `unwrap_used`/`expect_used` |
| `no-dynamic-code` | Report resolved evaluation APIs such as `eval` and any supported raw-code extension under a configurable restriction policy. Keep ordinary externals and safe dynamic data parsing out of scope. | Symbol identity plus syntax-extension classification | Oxlint `no-eval`, `no-implied-eval`, `no-new-func` |
| `no-shared-array-initializer` | Report when an array repetition/make API fills every slot with the same newly allocated mutable value. Recommend an initializer callback when the API provides one. | API identity and value mutability | Oxlint Unicorn `no-array-fill-with-reference-type`; Clippy `repeat_vec_with_capacity` concept |
| `no-floating-promise` | Report a promise explicitly discarded with `ignore` or a wildcard binding rather than awaited, returned, or stored. ReScript already rejects a bare promise-valued statement because statement positions require `unit`. | Expression types and async context | Oxlint TypeScript `no-floating-promises` |
| `require-await` | Report an `async` function with no reachable `await`, except interface adapters and deliberately promise-shaped callbacks. | Control flow; types for adapter exemptions | Oxlint `require-await`; Clippy `unused_async` |
| `no-await-in-loop` | Report sequential `await` in loops when iterations are independent; stay silent when later iterations depend on earlier results. This should initially be conservative and disabled. | Data/control flow | Oxlint `no-await-in-loop` |
| `only-used-in-recursion` | Report parameters captured only to pass unchanged to the same recursive binding. | Resolved recursive calls and use graph | Oxlint `only-used-in-recursion` |
| `eta-reduction` | Suggest `let f = g` for a wrapper that is provably equivalent. Do not alter labeled/optional argument behavior, partial application, attributes, arity, or exception timing. | Resolved callee type and arity | Zanuda `eta_reduction`; Clippy `redundant_closure` |
| `no-ignored-result` | Report explicit `ignore` calls and wildcard bindings for configured must-use types such as `result`. ReScript already rejects a bare non-`unit` expression in statement position. | Expression types and full application | Zanuda `wrong_ignoring`; Clippy must-use/result lints |
| `fuse-collection-pipeline` | Suggest safe fusions such as `map` followed by `map`, `filter` followed by `map`, or `map` followed by flatten when the resolved API provides an equivalent primitive. | Symbol identity, callback effects, and collection type | Zanuda `list_fusion`; Clippy `map_flatten`, `manual_filter_map` |
| `no-accumulating-concat` | Report repeated list/array/string concatenation in loops or left folds where it creates quadratic allocation. | Symbol identity and loop/fold context | Zanuda/Olint list and string concatenation rules; Oxlint `no-accumulating-spread` |
| `no-top-level-side-effect` | Optionally prohibit executable module-initialization effects outside named entry modules. | Effect/API classification and project entry points | Zanuda `no_toplevel_eval` concept, adapted to ReScript |
| `no-redundant-mutual-recursion` | Report `rec ... and ...` groups whose dependency graph does not require mutual recursion. | Resolved binding dependency graph | Zanuda `mutually_rec_types` |
| `prefer-standard-combinator` | Recognize hand-written `map`, `filter`, and fold recursions only when their semantics match a configured standard combinator. | Typed recursive-call analysis | Zanuda/Camelot manual map/fold rules; Clippy `manual_*` rules |

ReScript deliberately has both shallow and deep equality. A blanket ban on
either operator would be wrong: `===` is cheap and correct for primitive values,
while `==` is value equality but may invoke a runtime deep comparison for
compound values. The two proposed equality rules therefore require types.

### 3. JSX accessibility pack

Most Oxlint `jsx-a11y` concepts can apply to ReScript DOM JSX, but only after
the configured JSX runtime and its intrinsic-element/prop schema are known.
ReScript JSX is generic and prop spellings differ from JavaScript JSX (for
example, React bindings expose `ariaLabel` for `aria-label`). These must be an
adapter-backed `jsx-a11y/*` pack rather than unconditional string matching.
The compiler already rejects unknown props and values that violate the binding's
prop types, so `aria-props` and `aria-proptypes` are not lint candidates.

Candidate rules:

- `alt-text`
- `anchor-ambiguous-text`
- `anchor-has-content`
- `anchor-is-valid`
- `aria-activedescendant-has-tabindex`
- `aria-role`
- `aria-unsupported-elements`
- `autocomplete-valid`
- `click-events-have-key-events`
- `control-has-associated-label`
- `heading-has-content`
- `html-has-lang`
- `iframe-has-title`
- `img-redundant-alt`
- `interactive-supports-focus`
- `label-has-associated-control`
- `lang`
- `media-has-caption`
- `mouse-events-have-key-events`
- `no-access-key`
- `no-aria-hidden-on-focusable`
- `no-autofocus`
- `no-distracting-elements`
- `no-interactive-element-to-noninteractive-role`
- `no-noninteractive-element-interactions`
- `no-noninteractive-element-to-interactive-role`
- `no-noninteractive-tabindex`
- `no-redundant-roles`
- `no-static-element-interactions`
- `prefer-tag-over-role`
- `role-has-required-aria-props`
- `role-supports-aria-props`
- `scope`
- `tabindex-no-positive`

The implementation started with rules whose answer is local and unambiguous:
`alt-text`,
`anchor-has-content`, `heading-has-content`, `html-has-lang`,
`iframe-has-title`, `media-has-caption`, `no-access-key`,
`no-autofocus`, `no-distracting-elements`, `scope`, and
`tabindex-no-positive`. The later role and interactivity wave is also
implemented through the shared ARIA/DOM model. Dynamic props/spreads and custom
component polymorphism remain unknown rather than being treated as intrinsic
elements.

### 4. React pack

ReScript React only exposes function components, so class-component rules are
not relevant. These Oxlint React rules do transfer, subject to resolved React
bindings and the configured JSX transform:

| Proposed rule | Status | Notes |
| --- | --- | --- |
| `react/jsx-key` | Adapter | Detect missing keys in arrays and collection rendering, including fragments. |
| `react/no-array-index-key` | Adapter | Disabled performance/correctness rule; when enabled, allow demonstrably static lists. |
| `react/no-children-prop` | Adapter | Prefer JSX children when the resolved component contract permits it. |
| `react/no-danger-with-children` | Adapter | `dangerouslySetInnerHTML` and children are contradictory. |
| `react/void-dom-elements-no-children` | Adapter | Reject children on intrinsic void elements. |
| `react/button-has-type` | Adapter | Make accidental form submission explicit. |
| `react/jsx-no-target-blank` | Adapter | Require safe `rel` for untrusted `_blank` links. |
| `react/iframe-missing-sandbox` | Adapter | Opt-in security restriction with configurable exceptions. |
| `react/no-unstable-nested-components` | Typed | Detect component definitions recreated during render. |
| `react/jsx-no-constructed-context-values` | Typed | Detect newly allocated context values on every render. |
| `react/exhaustive-deps` | Typed | Requires hook identity, captured-variable analysis, and ReScript-specific dependency-array syntax. |
| `react/no-new-prop-value` | Typed | Combine Oxlint React-perf's four allocation-as-prop rules under a ReScript-native contract. |

The current `react/rules-of-hooks` remains separate. React Compiler rules such
as `immutability`, `purity`, `refs`, `set-state-in-render`, `static-components`,
and `use-memo` should be reconsidered only after their assumptions have been
validated against compiled ReScript and the supported React version. They are
not parser-only ports.

### 5. Test-framework adapters

These concepts are useful, but `describe`, `test`, `expect`, and modifiers are
ordinary ReScript bindings. Each supported test library needs a versioned API
adapter; spelling alone is not evidence. The initial examples and feasibility
check target `rescript-vitest` 3.0.1.

- `test/no-focused-tests`
- `test/no-disabled-tests`
- `test/no-identical-title`
- `test/no-duplicate-hooks`
- `test/no-conditional-test`
- `test/no-conditional-expect`
- `test/prefer-hooks-in-order`
- `test/prefer-hooks-on-top`
- `test/require-top-level-describe`
- `test/valid-title`
- `test/expect-expect`
- `test/max-nested-describe`

Do not create separate Jest and Vitest rule IDs if the observable ReScript
contract is identical. Put library-specific symbol recognition behind the
adapter. ReScript's types already reject async callbacks passed to Vitest's
synchronous `describe` and matcher calls with invalid arity, so
`test/valid-describe-callback` and `test/valid-expect` are delegated to the
compiler. The current binding exposes snapshot matching but not inline snapshot
text, so `test/no-interpolation-in-snapshots` is deferred until a supported
adapter has such an API.

### 6. Project rules

These use deterministic project discovery, module resolution, interface
precedence, and dependency metadata. They share the same bounded project
infrastructure as project-wide throws analysis.

| Proposed rule | Contract | Inspiration |
| --- | --- | --- |
| `no-restricted-modules` | Configurable architectural boundaries over canonical module/package identities. | Oxlint `no-restricted-imports` concept |
| `no-unused-export` | Report project-wide unused public values while honoring `.resi`, FFI, reflection/configured roots, and generated consumers. | Reanalyze DCE |
| `no-deprecated-api` | Report uses of declarations annotated deprecated, including dependencies. | TypeScript/Clippy deprecation lints; compiler metadata |
| `require-interface` | Optional policy for selected directories, never a universal default. | Zanuda `lint_filesystem` |
| `require-license-header` | Optional exact SPDX/header policy with generated-file exclusions. | Zanuda `top_file_license` |

Prefer integrating or consuming Reanalyze results for transitive dead values,
modules, types, record fields, variant constructors, and redundant optional
arguments. Reimplementing those analyses in a source-only pass would be a
regression in precision.

The ReScript build already rejects circular module dependencies and references
to the current compilation unit through its own generated module name. Those
fail before linting and are not implementation candidates.

## Oxlint disposition

The audited Oxlint catalog contained 870 entries: 187 ESLint, 138 Unicorn, 110
TypeScript, 85 React, 73 Vitest, 60 Jest, 46 Vue, 36 JSX accessibility, 33
Import, 27 Oxc, 23 JSDoc, 21 Next.js, 16 Promise, 11 Node, and 4 React-perf.

The rules explicitly listed in the preceding sections are the transfer
candidates. Every remaining Oxlint rule falls into one of the exclusions below;
it should not be copied under its JavaScript rule contract.

### Oxlint rules that do not directly work for ReScript

| Oxlint area | Disposition | Reason and examples |
| --- | --- | --- |
| TypeScript syntax and declarations | Reject | ReScript has no interfaces, namespaces, enums, type assertions, non-null assertions, overload declarations, access modifiers, or TypeScript module syntax. Examples: `adjacent-overload-signatures`, `consistent-type-assertions`, `no-explicit-any`, `no-extra-non-null-assertion`, `no-namespace`, `no-unnecessary-type-arguments`. The concept behind `no-floating-promises` is retained as a typed ReScript rule. |
| Vue | Reject | Vue SFC macros, directives, slots, emits, and template rules do not describe ReScript syntax. This excludes all 46 Vue rules. |
| Next.js | Reject | These inspect Next file conventions and JavaScript/React framework APIs. ReScript packages could add a future adapter, but they are not core rules. This excludes all 21 Next.js rules. |
| JSDoc | Reject | ReScript documentation comments and generated API docs do not use JSDoc's tag/type grammar. This excludes all 23 JSDoc rules. |
| Node/CommonJS globals | Reject as core | `require`, `module.exports`, `__dirname`, Buffer construction, callback error conventions, and CommonJS import placement are JavaScript concerns. Examples: `global-require`, `no-commonjs`, `no-exports-assign`, `no-new-require`, `no-process-exit`. A binding-specific API ban can be configured separately. |
| ECMAScript classes/prototypes/`this` | Reject | ReScript has no JavaScript class declaration, `super`, prototype mutation, method/accessor declaration, or class-field semantics. Examples: `accessor-pairs`, `class-methods-use-this`, `constructor-super`, `getter-return`, `no-dupe-class-members`, `no-proto`, `no-this-before-super`. |
| `var`, assignment, and declaration hoisting | Reject | ReScript bindings are lexical and immutable by default; JavaScript's `var`/`let`/`const` distinction and hoisting hazards do not exist. Examples: `block-scoped-var`, `init-declarations`, `no-func-assign`, `no-global-assign`, `no-use-before-define`, `no-var`, `prefer-const`, `vars-on-top`. |
| JavaScript coercion/dynamic-type hazards | Reject or Delegate | The ReScript type checker prevents loose equality, invalid `typeof`, constructor misuse, sparse arrays, most invalid property/call shapes, and implicit coercions. Examples: `eqeqeq`, `no-extra-boolean-cast`, `no-implicit-coercion`, `no-new-wrappers`, `no-sparse-arrays`, `use-isnan`, `valid-typeof`. A resolved `Float.isNaN` style rule could be proposed separately if real ReScript bugs justify it. |
| JavaScript import/export forms | Reject as syntax | ReScript module references, `open`, `include`, aliases, packages, and `.resi` files need native rules. Examples: `exports-last`, `extensions`, `group-exports`, `no-amd`, `no-anonymous-default-export`, `no-default-export`, `prefer-default-export`, `unambiguous`. Project-level concepts retained above use new contracts. |
| JavaScript object/destructuring/spread idioms | Reject | Object shorthand, computed keys, rest parameters, and JS destructuring transformations do not map safely to ReScript records/objects and labeled arguments. Examples: `object-shorthand`, `prefer-destructuring`, `prefer-object-spread`, `prefer-rest-params`, `no-useless-computed-key`. |
| JavaScript regex literal internals | Reject as core | Rules over regex flags, character classes, backreferences, and literal construction belong to the JavaScript regex engine or a dedicated regex parser, not the ReScript AST. Examples: `no-control-regex`, `no-empty-character-class`, `no-invalid-regexp`, `no-useless-backreference`, `prefer-regex-literals`, `require-unicode-regexp`. |
| JavaScript labels, `with`, `delete`, generators | Reject | The source constructs do not exist. Examples: `no-extra-label`, `no-labels`, `no-label-var`, `no-with`, `no-delete-var`, `require-yield`. |
| DOM/Web APIs | Adapter, not core | Rules such as `no-document-cookie`, `no-invalid-fetch-options`, `prefer-add-event-listener`, `prefer-query-selector`, and `require-post-message-target-origin` require exact binding identities and browser-version policy. Consider a separate Web API security/performance pack after generic API adapters exist. |
| Promise library style rules | Mostly reject | `avoid-new`, `no-new-statics`, `param-names`, `prefer-catch`, and similar rules assume JavaScript Promise constructor/method spelling. Retain only typed behavioral contracts such as floating promises, missing `await`, and defensible sequential-await diagnostics. |
| Jest/Vitest | Adapter | The concepts listed in the test section transfer; direct JavaScript callee/property matching does not. All other Jest/Vitest rules remain out until a supported ReScript test adapter needs them. |
| React classes and legacy APIs | Reject | ReScript React exposes function components, not the class API. Reject `no-did-mount-set-state`, `no-did-update-set-state`, `no-direct-mutation-state`, `no-is-mounted`, `no-redundant-should-component-update`, `no-string-refs`, `prefer-es6-class`, `require-render-return`, and `state-in-constructor`. |
| Generic JSX style rules | Delegate or reject | The formatter owns brace, fragment, self-closing, and layout style. The compiler catches duplicate props and invalid prop types. Examples: `jsx-boolean-value`, `jsx-curly-brace-presence`, `jsx-fragments`, `jsx-no-duplicate-props`, `self-closing-comp`. |
| Compiler-enforced React and test contracts | Delegate | ReScript React rejects unknown intrinsic props and invalid ARIA value types. Typed test bindings reject invalid callback return types and matcher arity. This covers `aria-props`, `aria-proptypes`, `react/no-unknown-property`, `test/valid-describe-callback`, and `test/valid-expect`. |
| Source formatting | Delegate | Whitespace, BOM, quote, semicolon, import ordering, and purely visual layout should be formatter responsibilities, except the existing intentionally specified `blank-lines` policy. Examples: `no-irregular-whitespace`, `sort-imports`, `unicode-bom`. |
| Broad identifier/style restrictions | Reject as defaults | `id-length`, `id-match`, `capitalized-comments`, `no-inline-comments`, `no-magic-numbers`, `no-plusplus`, `no-ternary`, and similar policies have high noise and little ReScript-specific correctness value. A future configuration engine may expose a small opt-in subset. |

### Oxlint ideas worth revisiting only with evidence

These are not scheduled rules, but are close enough to retain in the research
backlog: `bad-min-max-func`, `bad-comparison-sequence`, `number-arg-out-of-range`,
`array-callback-return`, `no-promise-executor-return`, `preserve-caught-error`,
`prefer-exponentiation-operator`, `radix`, `no-shadow`, `no-unmodified-loop-condition`,
`no-unreachable-loop`, `prefer-array-find`, `prefer-array-flat-map`,
`prefer-includes`, `prefer-set-has`, and `prefer-string-starts-ends-with`.
Each needs either a stable ReScript standard-library identity, type information,
or concrete examples showing that the compiler does not already catch the bug.

## OCaml linter disposition

The OCaml ecosystem does not have one canonical Clippy-sized catalog. The most
relevant sources were:

- Zanuda: an active typed-tree linter with 36 published entries.
- Camelot: a modular parse-tree teaching/style linter with 27 registered checks.
- Olint: a smaller source linter with 14 documented checks.
- The OCaml compiler warnings and Reanalyze, which own several semantic checks.
- Historical Ocamllint and Typerex/OCP-lint, useful as design references but not
  current rule authorities.

### OCaml ideas that transfer

The recommended tables above incorporate these OCaml-origin ideas:

- boolean simplification and boolean-switch-to-`if`
- catch-all exception swallowing
- physical versus structural equality
- list length used as an emptiness check
- partial list functions
- eta reduction with an arity/type proof
- collection-pipeline fusion
- repeated list/string concatenation
- excessive nested `if` expressions
- manual map/fold/filter implementations
- unnecessary mutual recursion
- discarded typed results / blanket `ignore`
- optional top-level-effect, interface, and license policies
- pattern-oriented simplifications such as replacing a one-arm identity switch
  only when the transformation remains clearer in ReScript syntax

### OCaml rules that do not transfer directly

- Zanuda `camel_cased_types` and generic naming checks: ReScript has its own
  lexical conventions and compiler diagnostics; do not import OCaml casing.
- `camel_extra_dollar`: ReScript does not use OCaml's `@@` application operator.
- `dont_disable_all_warnings`: OCaml warning attributes/configuration do not map
  directly; a ReScript-specific suppression audit belongs with future inline
  lint configuration.
- `expect_tests_no_names`: this targets OCaml `let%expect_test` syntax. A test
  adapter may instead require descriptive names for its own bindings.
- `format_module_usage`: OCaml `Format`/`Printf` directives and APIs differ from
  ReScript template strings and formatting libraries.
- `lint_filesystem`: requiring `.mli` files is OCaml-specific. The narrower
  optional `require-interface` rule must understand `.resi` conventions.
- `no_docs_parsetree`: this is a project-specific policy for AST definition
  files, not a general lint.
- `no_toplevel_eval`: OCaml's `;;` concern does not exist; only the broader
  optional top-level-effect policy transfers.
- `propose_function`: ReScript has no OCaml `function` keyword shorthand.
- `record_punning`: the ReScript formatter should own equivalent syntax
  normalization where supported.
- `tuple_matching`: replacing a switch with destructuring is contextual style,
  not universally clearer or safer.
- `use_guard_instead_of_if`: sometimes useful, but moving a condition into a
  guard can change exhaustiveness, evaluation, or readability. Keep it out until
  a narrow semantics-preserving contract is demonstrated.
- Zanuda's `misc_aggregate_defs`, `on_offer_prologue`, and
  `on_offer_epilogue` are implementation helpers, not user-facing rules.
- Camelot's line-length check is formatting policy. Its OCaml-specific literal
  prepend, tuple projection, and exact pattern-style checks need fresh ReScript
  contracts before consideration.

## Clippy disposition

Clippy is most valuable here as a source of language-independent bug patterns
and collection/performance smells. The following concepts are already captured
in the recommended tables or should be evaluated alongside them:

- `absurd_extreme_comparisons`, `impossible_comparisons`
- `approx_constant`
- `blocks_in_conditions`
- `bool_comparison`, `needless_bool`, `nonminimal_bool`
- `collapsible_else_if`, `collapsible_if`
- `comparison_chain`, `double_comparisons`, `redundant_comparisons`
- `empty_loop`, `infinite_loop`, `never_loop`, `single_element_loop`
- `erasing_op`, `identity_op`, `modulo_one`, `neg_multiply`
- `excessive_nesting`, `too_many_arguments`, `too_many_lines`
- `if_same_then_else`, `ifs_same_cond`, `same_functions_in_if_condition`
- `map_identity`, `filter_map_identity`, `flat_map_identity`
- `manual_filter`, `manual_filter_map`, `manual_find`, `manual_flatten`,
  `manual_map`, `unnecessary_fold`
- `match_bool`, `match_same_arms`, `needless_match`, `single_match`
- `only_used_in_recursion`
- `redundant_closure`, `redundant_else`, `redundant_guards`,
  `redundant_pattern_matching`
- `unnecessary_literal_unwrap`, `unwrap_used`, `expect_used` as input to the
  ReScript partial/unsafe API policy
- `unused_async`, `unused_result_ok`, and must-use result concepts

Do not port the following Clippy families:

| Clippy family | Disposition |
| --- | --- |
| Borrowing, ownership, moves, lifetimes, and drop order | Reject: ReScript has garbage collection and no Rust borrow checker. |
| `unsafe`, raw pointers, `Pin`, atomics, Send/Sync, and FFI ABI details | Reject: Rust-specific runtime and type-system contracts. ReScript FFI needs separate JS-interop rules. |
| Traits, impl blocks, associated items, `self`, visibility, and derive implementations | Reject: no matching ReScript constructs. |
| Macros, proc macros, token formatting, and edition/MSRV rules | Reject: no Rust macro or edition model. |
| Cargo features, manifests, crate versions, package metadata | Reject: ReScript uses `rescript.json` and npm/package conventions; any config rules need native contracts. |
| Rustdoc and intra-doc links | Reject: ReScript documentation generation has different syntax and tooling. |
| Rust integer casts, layouts, endian conversions, and platform ABIs | Reject directly: ReScript's JavaScript target and integer model require independent rules. |
| Exact Rust `Iterator`, `Option`, `Result`, `Vec`, `String`, filesystem, and synchronization APIs | Reject as direct ports. Reuse only a behavioral idea after mapping it to a resolved, versioned ReScript API. |
| Compiler-enforced exhaustiveness, reachability, unused bindings, and type errors | Delegate to the ReScript compiler unless the proposed rule demonstrably adds project-wide information. |
| Pure preference rules with opposing valid styles | Reject as defaults. Examples include blanket bans on `else`, early return, matching, loops, indexing, or particular collection combinators. |

Every Clippy lint not named in the candidate list is excluded as a direct port
by one of those families. New proposals should cite the ReScript behavior they
target, not merely a similarly named Clippy lint.

## Shared infrastructure status

The catalog implementation added the following shared capabilities. Remaining
work is called out explicitly where a capability is still deliberately bounded:

1. A rule registry with stable IDs, default activation, per-file overrides, and
   inline suppression parsing/auditing. Rule configuration is enabled/disabled
   only; enabled findings are always errors. A shipped JSON schema and an
   effective-configuration inspector remain outstanding.
2. A bounded canonical index over project-local `.res` and `.resi` sources,
   opens, includes, module aliases, and lexical shadowing. Narrow dependency
   adapters, such as throws contracts, do not provide a general dependency
   symbol index. Arbitrary opaque or generated exports remain unknown.
3. Bounded source type/identity inference and fresh Reanalyze-report validation;
   stale or missing required inputs produce analysis failure rather than a clean
   result. This is not a general compiler type lookup.
4. Versioned standard-library and ecosystem API inventories shared by banned,
   partial, promise, React, and test rules. A Web API adapter remains a separate
   future pack.
5. A small control-flow/effect model that distinguishes safe constant folding
   from transformations that remove evaluation, exceptions, mutation, or I/O.
6. Explicit JSX, test-framework, throws-runtime, and project-root adapters.
7. Safe automatic fixes through the existing edit pipeline, with formatter and
   convergence validation. Review-only suggestions remain a future UX decision.

## Acceptance policy

A new rule is ready to enable by default only when:

- its ReScript-specific bad and good examples are documented;
- aliases, opens, shadowing, nested modules/functions, and callbacks are tested
  wherever they affect the contract;
- the rule states whether it is syntax-only, typed, adapter-specific, or
  project-wide;
- missing semantic information cannot silently turn an unknown result into a
  clean result;
- fixes preserve comments, evaluation order, exception behavior, and formatter
  stability;
- false-positive behavior is low enough to enforce the rule as an error when it
  is enabled; and
- the compiler, formatter, or Reanalyze does not already provide the same result
  with better precision.

## Sources

- [Oxlint rule catalog](https://oxc.rs/docs/guide/usage/linter/rules.html) (870
  entries in the 2026-09-20 snapshot)
- [Oxlint categories and configuration](https://oxc.rs/docs/guide/usage/linter/config.html)
- [Clippy lint catalog](https://rust-lang.github.io/rust-clippy/stable/index.html)
- [Zanuda rule catalog](https://kakadu.github.io/zanuda/lints/index.html) and
  [repository](https://github.com/Kakadu/zanuda)
- [Camelot registered checks](https://github.com/upenn-cis1xx/camelot/blob/master/lib/style/checkers.ml)
- [Olint rule list](https://github.com/Zaneham/Olint#rules)
- [OCaml linting tools survey](https://sim642.eu/blog/2024/05/01/ocaml-linting/)
- [Reanalyze analyses](https://github.com/rescript-lang/reanalyze) and
  [ReScript editor analysis](https://rescript-lang.org/docs/manual/editor-plugins/)
- [ReScript equality and comparison](https://rescript-lang.org/docs/manual/equality-comparison/)
- [ReScript async/await](https://rescript-lang.org/docs/manual/function/#asyncawait)
- [ReScript JSX](https://rescript-lang.org/docs/manual/jsx/) and
  [ReScript React component prop conventions](https://rescript-lang.org/docs/react/components-and-props/)
