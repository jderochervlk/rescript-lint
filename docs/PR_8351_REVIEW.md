# ReScript PR 8351 Prior-Art Review

Reviewed 2026-09-21. [Upstream PR #8351][pr] is an open draft, last updated
2026-04-20. This review pins its final commit at
`9b7a9252c143615a4d2b2abaf589d572b72021c0`; links below refer to that revision.
The initial comparison used this repository's working tree over
`2beb32d4a53fdb650e7a9835b85167376736c559`, including in-progress changes.
The current-state notes below were reconciled after the catalog, configuration,
and LSP work landed. This is a source review, not a claim that the prototype was
built or executed.

The strongest additions are richer reference restrictions, declaration-origin
boundaries, effective-configuration inspection, and a configuration schema.
The normalization rules are useful optional policies, but need tighter safety
contracts before adoption. This document does not itself implement any
recommendation.

## Scope and Evidence

The PR description names an earlier command layout. At the reviewed commit,
the executable is `rescript-assist`, with `lint check`, `rewrite run`,
`support active-rules`, `support show`, and `support find-references`.
The [command dispatcher][cli] and [design document][design] establish this
distinction. Git filtering, repeated rewriting to a fixed point, and semantic
verification of rewritten programs are discussed as plans; they should not be
counted as delivered capabilities.

The rule inventory below was checked against [analysis][analysis],
[rewrite implementation][rewrite], [rule metadata][shared],
[configuration defaults][config], and the [fixtures and golden outputs][tests].
Local comparisons use the actual [registry](../lib/rule_config.ml),
[project rules](../lib/project_rules.ml), [semantic walker](../lib/semantic_walk.ml),
and [extended contracts](EXTENDED_RULES.md), rather than matching rule names alone.

## Implemented Rule Gaps

The PR implements five lint rules and three rewrite rules: seven distinct IDs,
because `preferred-type-syntax` appears in both namespaces. We have partial
coverage for one lint rule, lack the other four lint policies, and implement
none of these three rewrites. The table describes upstream behavior, not
configuration accepted by this linter.

| Upstream rule | Actual scope in the PR | Coverage here | Recommendation |
| --- | --- | --- | --- |
| `forbidden-reference` (lint) | Typed reference matching with module-prefix bans and exact value/type bans; configurable messages per policy and item. | **Partial.** `no-restricted-modules` matches canonical prefixes on value and module references, including supported lexical aliases, opens/includes, and configured project shadows. There is no explicit kind distinction, type-use traversal, or custom policy message. The fixed `no-console`, `no-object-magic`, and `no-unsafe` inventories are not general policy configuration. | Extend the restriction policy deliberately, retaining compatibility with `restrictedModules`; add type-reference coverage and kind-specific matching. |
| `forbidden-source-root-reference` (lint) | Matches the resolved declaration's source file against configured roots for value/type references. Files inside the matching root are exempt. | **Missing.** `exclude` controls which files are discovered; it does not prohibit consumers from referencing their declarations. Module-name bans do not establish declaration origin. | Adopt as an opt-in architectural rule after declaration provenance is available. |
| `single-use-function` (lint) | Combines AST function bindings with typed, same-file reference counts; only non-exported functions with exactly one use are reported. | **Missing.** `no-unused-export` concerns unused public declarations; `only-used-in-recursion` concerns parameters; `eta-reduction` concerns forwarding wrappers. | Defer or keep opt-in. A single use does not establish that a helper is unnecessary. |
| `alias-avoidance` (lint) | AST checks for aliases of qualified values, type manifests, and modules, including supported signature/local-module forms. | **Missing.** Resolving aliases for another rule does not prohibit declaring them. | Consider a narrowly configurable, opt-in policy; resolve the conflict with `eta-reduction` first. |
| `preferred-type-syntax` (lint) | Reports `Dict.t<_>` and `Stdlib.Dict.t<_>` when the `dict` setting is enabled, in `.res` and `.resi`. | **Missing.** No current rule enforces these spellings. | Adopt as an opt-in policy once standard-library identity is established. |
| `prefer-switch` (rewrite) | Converts eligible `if`/ternary expressions to boolean switches; chains become ordered guards on `switch ()`. Separate `if` and ternary toggles. | **Missing.** Our control-flow checks detect redundant or suspicious conditions, not branch-style preferences. | Defer broad normalization; keep it explicitly separate from routine lint fixes if implemented. |
| `no-optional-some` (rewrite) | Converts an optional labeled argument containing unqualified `Some(expr)` into a direct labeled argument. | **Missing.** The Reanalyze delegation discussed in our candidate plan is not this source rewrite. | Good candidate for an opt-in diagnostic and, after validation, a narrow fix. |
| `preferred-type-syntax` (rewrite) | Replaces the two supported dictionary type paths with builtin `dict`, including nested type arguments. | **Missing.** `blank-lines` is our existing fix-producing rule. | Share recognition with the proposed lint rule; offer a fix only when identity and source preservation are proven. |

### Restriction Semantics Worth Preserving

Within a `forbidden-reference` instance, the PR prefers an exact value/type
match over a module-prefix match, then the longest matching module prefix.
Item messages override the enclosing policy message. Across instances, the
first matching enabled instance wins. These are concrete, testable precedence
rules in [the matcher][analysis]. Adopt explicit precedence when adding policy
entries here; do not leave overlapping policies dependent on incidental map or
traversal order.

Our current limitation is visible in `Project_rules.reference_findings`:
callbacks inspect `Pexp_ident` and module references, but not core type uses.
For example, a restricted type mentioned only in an annotation or `.resi`
does not receive equivalent coverage. Extending the shared semantic traversal
is necessary; adding another string list alone would not close that gap.
Keep unknown resolution explicit, and test module/value/type namespace
collisions, opens, aliases, includes, nested modules, and lexical shadows.

The source-root rule follows declaration metadata, resolves existing paths
through `realpath`, and checks directory boundaries rather than arbitrary
string prefixes. Its roots are relative to the config file; the first matching
root determines the finding. It exempts a consumer only when that consumer is
inside the particular matched root. It does not cover module references,
record-field accesses, or constructor references as source-root kinds.
Preserve these distinctions in the first contract, or explicitly expand them.
Our [semantic value model](../lib/semantic_model.mli) does not currently carry
the declaration source path needed for equivalent behavior.

### Style Policies Need Independent Decisions

`single-use-function` defaults to enabled/warning upstream. Its implementation
subtracts one definition entry from the typed reference list and checks for one
remaining reference. Although the design document proposes excluding recursive
functions, the implementation has no explicit recursion exclusion. Do not copy
that counting assumption into our model without verifying the reference format.
Exclude recursion, public exports, and uncertain generated bindings explicitly;
never automatically inline based solely on the count.

`alias-avoidance` also defaults to enabled/warning upstream. Its qualified-path
test does not flag every alias: for example, `module M = Other` and `let y = x`
do not satisfy its dotted-path requirement. It does flag public value/type
aliases, which can intentionally define a stable API. Meanwhile, our
[`eta-reduction`](../lib/semantic_recursion.ml) suggests replacing eligible
forwarding wrappers with aliases. Enabling both policies without exemptions
would produce conflicting guidance. Scope alias avoidance to an agreed context
or define how both rules arrive at the same acceptable form.

`preferred-type-syntax` has `enabled = true` but `dict = false` by default in
both upstream namespaces, so it is initially inactive. Recognition is by
spelling, without checking whether a project shadows `Dict` or `Stdlib`.
Before offering either a diagnostic or a fix here, resolve the standard-library
type identity, including `.resi` contexts. Otherwise a custom `Dict.t` could be
changed to an unrelated type.

For `no-optional-some`, the intended transformation is:

```rescript
// Before
let result = consume(~value=?Some(compute()), ())
// After
let result = consume(~value=compute(), ())
```

Preserve evaluation count/order, argument labels, partial application, comments,
and meaningful attributes. Leave `None` and arbitrary option-valued expressions
alone. The upstream mapper matches the syntactic `Some` node and replaces it
with its inner expression; it does not establish a general preservation proof.
Use compiler-checked fixtures before claiming this is safe autofix behavior.

## Changes to Adopt

### 1. Report Effective Configuration

The PR's [`support active-rules`][active] lists configured activation, settings,
descriptions, and policy instances in text or JSON. Our `--list-rules` reports
only built-in defaults and is parsed as a standalone option in
[`command.ml`](../lib/command.ml). It cannot explain a project's resolved policy.

Add an explicit effective-configuration command using the same configuration
and CLI precedence as lint, watch, fix, and LSP. Report enabled state, options,
adapter requirements, and configuration origin. Distinguish enabled from
actually analyzable: upstream's `active` field does not verify typed-artifact
availability. Keep the existing default inventory useful and stable.

Acceptance: a config override and subsequent CLI override produce the same
effective rule set for the inspector and lint; missing adapter requirements
remain visible; text and JSON describe the same settings deterministically.

### 2. Ship a Schema for Our Own Configuration

The [upstream schema][schema] provides editor completion for rule names and
options. We have strict runtime decoding in [config_file.ml](../lib/config_file.ml)
but no shipped configuration schema, and `$schema` is currently an unknown
property. Add a schema for our existing flat format, allow a string `$schema`
as editor metadata without fetching it, and include the schema in npm packages.
There is no need to adopt the prototype's lint/rewrite namespaces to gain this.

Acceptance: test registry/schema agreement and valid/invalid config examples,
including unknown keys, adapter enums, numeric limits, and duplicate keys at
the runtime decoder. A schema does not replace runtime validation. In
particular, the upstream decoder defaults some malformed booleans/severities;
retain our strict rejection behavior.

### 3. Give Policy Findings Actionable Context

Adopt per-restriction guidance such as the supported replacement API, together
with the resolved symbol and a documentation link where available. Upstream
already supports item/rule messages and includes a `symbol` field. Its text
reporter also supplies source snippets through [shared output helpers][support].

Our [diagnostic type](../lib/diagnostic.mli) currently contains the rule, message,
filename, range, and edits. The [JSON reporter](../lib/json_reporter.ml) already
supplies a versioned envelope and reserves `help` as `null`; JSON output itself
is therefore not a missing feature in this comparison. Introduce typed
help/symbol metadata consistently across terminal, JSON, and LSP boundaries;
consider optional code frames without changing byte-range semantics. Custom
guidance must supplement an identifiable violation and retain the rule ID.

### 4. Introduce Typed Capabilities Only Where Needed

The prototype reuses the compiler analysis stack for symbol identities,
declaration origins, and reference counts. This is a useful model for the
restriction gaps, especially provenance through aliases and public interfaces.
Keep syntax checks usable without a build and isolate compiler-specific facts
behind an adapter that returns explicit success or analysis failure.

Our build currently links the parser adapter, not upstream's full `Analysis`
library; see [dependencies](DEPENDENCIES.md) and [lib/dune](../lib/dune).
Reusing `Cmt`, `ProcessCmt`, `References`, and `QueryEnv` would expand that build
boundary. Evaluate that cost against a bounded extension of our existing
project/signature model. Merely having those files in `vendor/rescript` does not
make their APIs available to our linter. Any new dependency needs a separate
implementation decision and the repository's dependency approval process.

Require compatible, fresh artifacts and define behavior for unsaved LSP buffers.
Our [Reanalyze adapter](../lib/reanalyze_report.ml) already demonstrates explicit
missing/stale-input failure. Do not weaken that contract for new typed rules.

### 5. Reuse the Fixture Strategy and Add Safety Cases

The PR supplies `.res`/`.resi`, built-project, unbuilt-file, whole-project,
human/JSON, rewrite-source, and diff snapshots. Adopt that breadth for new
policies while testing observable behavior through our existing test harness.

For restriction work, include exact-vs-prefix precedence, type-only consumers,
declaration provenance through aliases, interface precedence, same-root
exemptions, sibling-prefix paths, symlinks, dependencies, and unavailable or
stale metadata. For fixes, include invalid input, comments/attributes, Unicode
ranges, conflicting edits, evaluation order, and second-run idempotence.
Test combinations with `eta-reduction`, `blank-lines`, suppressions, and the
formatter, not only each rule in isolation.

## Behaviors to Change Before Reusing the Prototype

| Observed upstream behavior | Required adaptation here |
| --- | --- |
| `analyze_file` does nothing for typed rules when loading metadata returns `None`; the unbuilt forbidden-reference fixture expects an empty result. | Emit an analysis failure when an enabled check needs unavailable facts. Do not equate skipped analysis with a clean file. |
| Warnings and errors are configurable upstream; either can make `has_findings` true. | Preserve our binary enable/disable policy and error status for enabled findings. Subjective new policies stay opt-in. |
| Config discovery searches parent directories, preferring `.rescript-lint.json` over `rescript-lint.json` at each level. | Consider separately, after defining project/workspace stopping points and explicit `--config` precedence. Expose the selected file in effective configuration. Avoid silently inheriting an unrelated parent policy. |
| Rewrite uses the full AST printer, defaults to writing, and implements a single recursive mapping pass. | Keep broad normalization a distinct explicit operation; provide a read-only diff preview and verify convergence before claiming fixed-point behavior. Narrow lint fixes should use our edit pipeline. |
| `rewrite_file` ignores the initial parse's `invalid`/diagnostics fields and reparses only the produced output. | Reject invalid original input before considering edits; reparsing a recovered-and-reprinted tree cannot prove the original program was preserved. |
| `verify_rewritten_source` checks parsing, without typechecking or behavioral comparison. | Do not describe reparsing as semantic verification. Validate language-level equivalence for each fix; compiler-check fixtures and use stronger validation for aggressive transforms. |
| The PR combines linting with `show` and `find-references` commands. | Reuse the semantic-query ideas if needed, but defer these product features. Our current request is a linter; full hover/reference tooling is a separate scope decision. |

Our [fixer](../lib/fixer.ml) already rejects invalid/conflicting edits, relints,
checks that fixes converge, and checks formatter compatibility for spacing.
Any additional fix must preserve these guarantees. Its spacing-oriented
validation is not by itself an equivalence check for new semantic rewrites.

## Scratchpad Ideas, Not Implemented Upstream Rules

The [design document's candidate sections][design] contain further ideas.
They are recorded here to avoid losing useful prior art, but must not inflate
the inventory of implemented missing rules.

| Candidate idea | Relationship to this repository | Disposition |
| --- | --- | --- |
| React component interfaces, component-only exports, and requiring component declarations for JSX-returning helpers | `require-interface` provides a general file-interface policy, not props-specific or export-shape validation. None of the component-only/JSX-helper policies is implemented. | Consider optional React adapter policies only after defining HMR and binding-specific contracts. |
| Ban `@obj external`; presets named `no-obj-magic`, `no-raw`, `no-obj-external` | `no-object-magic` already covers the cast policy; `no-dynamic-code` covers supported raw-JS forms and dynamic APIs. An `@obj external` policy is missing. | Avoid duplicate IDs for existing checks; assess `@obj` independently because legitimate FFI uses exist. |
| File, function, and JSX size limits | `max-lines-per-function` exists; whole-file and JSX-specific limits do not. | Keep additional size policies opt-in and define counting rules first. |
| Naming conventions and configurable regex validation | No generic naming/regex policy exists. | Defer until concrete conventions justify a bounded design. |
| Ordinary strings instead of interpolation-free template strings | No equivalent normalization rule exists. | Optional candidate, with escaping and multiline semantics tested. |
| Dict spreads/literals instead of helper-based merges/construction | No equivalent dict-normalization rule exists. | Require resolved API identity, mutation behavior, key ordering, and evaluation-order checks. |
| Required props on configurable JSX elements; replace anchors with a designated `Link` component | Existing accessibility/React rules cover particular required props, not arbitrary component policies or a designated `Link`. | Potential adapter extension; distinguish existing accessibility checks from a configurable design-system policy. |
| Folder-scoped presets/messages, changed-line filtering, and enclosing-block git filtering | These are configuration/reporting ideas, not additional lint implementations. | Defer; reporting filters must not narrow the analysis required to establish a finding. |

## Suggested Order

1. Complete live Zed validation and prerelease distribution for the already-built
   LSP. This is the immediate release gate, not a reason to add more rules.
2. Add effective-configuration inspection and a shipped schema. These make
   existing policies easier to understand without changing their meaning.
3. Specify richer restrictions, including type-use coverage, custom guidance,
   and overlap precedence. Choose the semantic adapter before implementing
   declaration-origin restrictions.
4. Implement `no-optional-some` and `preferred-type-syntax` as opt-in diagnostics,
   followed by fixes only after compiler-checked preservation cases pass. Revisit
   alias avoidance and single-use helpers only after explicit policy choices;
   defer broad `prefer-switch` rewriting and support-query commands.

[pr]: https://github.com/rescript-lang/rescript/pull/8351
[cli]: https://github.com/rescript-lang/rescript/blob/9b7a9252c143615a4d2b2abaf589d572b72021c0/tools/bin/ai_cli.ml
[design]: https://github.com/rescript-lang/rescript/blob/9b7a9252c143615a4d2b2abaf589d572b72021c0/docs/rescript_ai.md
[analysis]: https://github.com/rescript-lang/rescript/blob/9b7a9252c143615a4d2b2abaf589d572b72021c0/tools/src/lint_analysis.ml
[rewrite]: https://github.com/rescript-lang/rescript/blob/9b7a9252c143615a4d2b2abaf589d572b72021c0/tools/src/rewrite.ml
[shared]: https://github.com/rescript-lang/rescript/blob/9b7a9252c143615a4d2b2abaf589d572b72021c0/tools/src/lint_shared.ml
[config]: https://github.com/rescript-lang/rescript/blob/9b7a9252c143615a4d2b2abaf589d572b72021c0/tools/src/lint_config.ml
[active]: https://github.com/rescript-lang/rescript/blob/9b7a9252c143615a4d2b2abaf589d572b72021c0/tools/src/active_rules.ml
[schema]: https://github.com/rescript-lang/rescript/blob/9b7a9252c143615a4d2b2abaf589d572b72021c0/docs/docson/rescript-lint-schema.json
[support]: https://github.com/rescript-lang/rescript/blob/9b7a9252c143615a4d2b2abaf589d572b72021c0/tools/src/lint_support.ml
[tests]: https://github.com/rescript-lang/rescript/tree/9b7a9252c143615a4d2b2abaf589d572b72021c0/tests/tools_tests
