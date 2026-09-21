# Extended Rule Reference

The catalog expansion adds 83 optional rules to the earlier 22, for **105**
registered IDs. `--list-rules` is the authoritative activation inventory. The
twelve previous defaults are unchanged. All enabled findings are errors; no
severity downgrades or automatic rewrites were added for these rules.

## Configuration

```sh
rescript-lint --config rescript-lint.json
rescript-lint --jsx-runtime react-dom --enable-rule jsx-a11y/alt-text src/View.res
rescript-lint --test-framework rescript-vitest-3 --enable-rule test/no-focused-tests src/View_test.res
rescript-lint lsp --stdio --config rescript-lint.json
```

```json
{
  "root": ".",
  "jsxRuntime": "react-dom",
  "testFramework": "rescript-vitest-3",
  "rules": {
    "jsx-a11y/alt-text": true,
    "react/jsx-key": true,
    "test/no-focused-tests": true,
    "no-deprecated-api": true,
    "no-restricted-modules": true
  },
  "restrictedModules": ["LegacyDatabase"],
  "entryModules": ["Main"],
  "exclude": ["src/generated"],
  "license": "MIT",
  "maxNesting": 4,
  "maxParams": 5,
  "maxLinesPerFunction": 50,
  "maxNestedDescribe": 5,
  "deepEqualityThreshold": 4
}
```

Paths are relative to the configuration file. CLI settings are applied in order;
later explicit settings win. Unknown properties, adapters, rule IDs, invalid
types, duplicate configuration/rule keys and negative limits are rejected. Deep-equality
risk thresholds must be at least 2. Selecting JSX or test rules without their
adapter produces an analysis error, not a clean result.

Optional `"throwsRuntime": "rescript-12.3.1"` or
`--throws-runtime rescript-12.3.1` loads the pinned runtime throws adapter and
activates checking in every requested file. `null` removes it. Unlike JSX/test
adapters, it extends the existing default throws rule; it is not required for
local/project contracts. See [the exact inventory and limits](THROWS.md#pinned-runtime-adapter).

Project discovery reads `rescript.json` sources as strings, objects with `dir`
and boolean `subdirs`, or lists of those forms. Missing sources defaults to
recursive `src`. Source directories must remain inside the project; symlinks,
generated build folders, dependencies and configured path-prefix exclusions are
skipped. Duplicate module names are rejected. Explicit filenames retain their
argument order. This is not workspace/package dependency resolution.

## Semantic Rules

These rules use source-inferred facts, lexical identities, the pinned runtime
API inventory and, when configured, project signatures. An explicit `.resi`
takes precedence over inferred implementation exports. Destructured declarations
retain their exported names; opaque module expressions and includes remain
unresolved rather than being treated as empty interfaces. Unknown facts are not
assumed pure, immutable, independent or equivalent. Matching candidates that
need unresolved type information can return an explicit analysis failure.

| Rule | Reported condition |
| --- | --- |
| `no-self-compare` | Repeated identity comparison when known value semantics make it redundant |
| `no-unintended-shallow-equality` | Physical equality on known compound values |
| `no-expensive-deep-equality` | Structural equality above the configured type-risk threshold |
| `no-float-equality` | Equality comparisons on known floating-point values, excluding literal sentinel checks |
| `prefer-pattern-check` | Supported constructor comparisons better expressed by matching; efficient payload-free checks are exempt |
| `prefer-empty-check` | Supported collection-size comparisons equivalent to an empty check |
| `no-partial-function` | Known partial/throwing runtime APIs; invalid-value unsafe APIs remain under `no-unsafe` |
| `no-dynamic-code` | Known dynamic-code APIs and raw-JavaScript expressions |
| `no-shared-array-initializer` | Shared mutable initializer passed to supported array construction |
| `no-floating-promise` | Known promise values discarded rather than handled or returned |
| `require-await` | Async functions without effective await or a returned promise |
| `no-await-in-loop` | Await in a loop whose iterations are provably or explicitly independent |
| `only-used-in-recursion` | A function parameter only forwarded through supported recursive calls |
| `eta-reduction` | Safe full-arity forwarding wrappers with matching labels and no semantic narrowing |
| `no-ignored-result` | Known Result values discarded without handling their cases |
| `fuse-collection-pipeline` | Supported adjacent collection stages with known-pure callbacks |
| `no-accumulating-concat` | Supported recursive accumulation that repeatedly copies a growing collection |
| `no-top-level-side-effect` | Effectful module initialization outside configured entry modules |
| `no-redundant-mutual-recursion` | Recursive groups without the corresponding dependency cycle |
| `prefer-standard-combinator` | Supported recursive shapes equivalent to known standard combinators |

`@lint.pure` and `@lint.independent` are explicit trust contracts for the relevant
purity/loop analyses, not facts checked by this linter. Do not add them merely to
silence a finding. Local inference is deliberately incomplete: advanced functors,
opaque dependencies, arbitrary external effects and whole-program typing are
outside its guarantee. No finding does not prove an optimization is safe.

## JSX Accessibility

All IDs below use the `jsx-a11y/` prefix and require `react-dom`. Recognition is
grounded in ReScript React 0.15 bindings and the WAI-ARIA 1.2 role model, not
JavaScript JSX property spelling. Intrinsic elements, static props, children,
literal roles and known visibility are analyzed. Dynamic props/spreads and
unknown custom-component output remain unknown, not definitely absent.

| Area | Rule suffixes |
| --- | --- |
| Names/content | `alt-text`, `anchor-ambiguous-text`, `anchor-has-content`, `control-has-associated-label`, `heading-has-content`, `iframe-has-title`, `img-redundant-alt`, `label-has-associated-control` |
| Links/language/media | `anchor-is-valid`, `autocomplete-valid`, `html-has-lang`, `lang`, `media-has-caption`, `no-distracting-elements`, `scope` |
| ARIA | `aria-activedescendant-has-tabindex`, `aria-role`, `aria-unsupported-elements`, `no-interactive-element-to-noninteractive-role`, `no-noninteractive-element-to-interactive-role`, `no-redundant-roles`, `prefer-tag-over-role`, `role-has-required-aria-props`, `role-supports-aria-props` |
| Interaction/focus | `click-events-have-key-events`, `interactive-supports-focus`, `mouse-events-have-key-events`, `no-access-key`, `no-aria-hidden-on-focusable`, `no-autofocus`, `no-noninteractive-element-interactions`, `no-noninteractive-tabindex`, `no-static-element-interactions`, `tabindex-no-positive` |

These checks do not replace browser accessibility testing, computed styles,
cross-component ID resolution, or assistive-technology validation. Supported
role/property tables and precision follow-ups are recorded in
[the JSX work log](RULE_WORK_JSX.md).

## React Rules

These twelve IDs use the `react/` prefix and require `react-dom`. The older
default `react/rules-of-hooks` keeps its separate documented syntax contract.

- `jsx-key`: missing keys in supported array/list JSX generation.
- `no-array-index-key`: keys derived from the actual callback index parameter
  of supported standard/Belt collection APIs.
- `no-children-prop`: explicit JSX children props.
- `no-danger-with-children`: both inner HTML and children.
- `void-dom-elements-no-children`: children or inner HTML on void DOM tags.
- `button-has-type`: missing explicit `type_` on buttons.
- `jsx-no-target-blank`: external new-context links without protective `rel`.
- `iframe-missing-sandbox`: iframe without a declared sandbox.
- `no-unstable-nested-components`: component declarations during render.
- `jsx-no-constructed-context-values`: fresh values supplied to a resolved
  `React.Context.provider` during render.
- `no-new-prop-value`: fresh arrays, records, tuples or functions passed as
  non-special props during render.
- `exhaustive-deps`: missing captured reactive values in supported React hook
  dependency arrays/tuples, including the binding's numbered variants.

Hook checks track identity and field paths, exclude module-level values and
known stable setters/refs, and respect aliases/shadowing. They are not React's
compiler, do not infer arbitrary custom-hook contracts, and do not rewrite
dependency lists. Dynamic callback/dependency expressions can remain unknown.

## Test Rules

All IDs use the `test/` prefix and the explicit `rescript-vitest-3` adapter,
verified against rescript-vitest 3.0.1. Other libraries with similarly named
functions are not silently treated as Vitest.

`no-focused-tests`, `no-disabled-tests`, `no-identical-title`,
`no-duplicate-hooks`, `no-conditional-test`, `no-conditional-expect`,
`prefer-hooks-in-order`, `prefer-hooks-on-top`, `require-top-level-describe`,
`valid-title`, `expect-expect`, and `max-nested-describe` inspect resolved test
registrations, suites, hooks, callback execution contexts and assertions.
Aliases, known project opens, nested suites and supported parameterized APIs
are covered. Opaque callback helpers and arbitrary runtime registration are not
whole-program analyzed. Disabled-test checks include literal `skip=true`, Todo
registrations and resolved runtime `skip`/`skipIf(true)` calls; a dynamic
`skipIf` condition is not assumed true. Duplicate titles compare literal titles
of sibling registrations of the same kind. The default maximum suite depth is
five. Details: [test adapter log](RULE_WORK_TESTS.md).

## Project Rules

- `no-restricted-modules`: canonical references to configured module prefixes;
  requires a nonempty `restrictedModules` list.
- `no-deprecated-api`: resolved references carrying `@deprecated`, including
  public interface metadata and local aliases.
- `require-interface`: implementation modules lacking a matching `.resi` in
  the configured source set. Interface files themselves are exempt.
- `require-license-header`: an ordinary leading comment with the exact
  `SPDX-License-Identifier: LICENSE` line, defaulting to MIT. A string or comment
  after code is not a license header.
- `no-unused-export`: public declaration findings from a fresh Reanalyze report,
  exempting configured entry modules. It never guesses exports are unused from
  a single-file reference count.

For unused exports, build the project with the compatible compiler, run its
`rescript-tools reanalyze -dce -json` command, save that JSON, and set
`reanalyzeReport` to the report path. The linter checks saved sources, matching
`.cmt`/`.cmti` files under `lib/ocaml` or legacy `lib/bs`, and timestamps. Missing,
stale, malformed or incompatible inputs fail analysis. Timestamps are a
freshness guard, not cryptographic evidence of artifact provenance. The linter
does not launch the compiler or analyzer itself.

## Suppressions

Ordinary comments support exact IDs separated by spaces or commas:

```rescript
// rescript-lint-disable-next-line no-console -- audited diagnostic output
Console.log("ready")
// rescript-lint-disable no-console -- scoped compatibility bridge
Console.log("legacy")
// rescript-lint-enable no-console
```

`rescript-lint-disable-line` targets its line. `disable-next-line` skips blank
and comment-only lines to the next syntax-bearing line. Regions nest per rule
and can run to EOF. Optional nonempty reasons follow `--`. Unknown/malformed IDs,
unmatched enables and unused suppressions are unsuppressible `suppression`
errors, including duplicate IDs within one directive. Usage is tracked per rule;
line directives take precedence over regions, so redundant suppressions are
reported as unused. A suppressed finding's fixes are also removed. Doc attributes, string
contents and annotation payloads do not create directives. Parse, I/O, fix and
analysis errors cannot be suppressed. See [suppression log](RULE_WORK_SUPPRESSIONS.md).

## Verification Notes

The [overnight log](RULE_OVERNIGHT_LOG.md) records staged failures, grouped
follow-ups and final verification. Compiler-checked examples are audited
separately from parser-only rule unit tests; examples needing project or policy
context must be evaluated with that context. Exact rule contracts take
precedence over a misleading example, not the other way around.
