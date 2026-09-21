# Throws Analysis

Implemented against the pinned ReScript 12.3.1 parser. Project declaration
contracts were added on 2026-09-21. This is bounded annotation enforcement, not
complete checked-exception or whole-program effect inference.

## What runs today

Without a runtime adapter, `--project DIR` or a configured `root`, the pass retains source-local
behavior: it activates only when the current file contains `@throws` or legacy
`@raises`. Passing several explicit files alone does not link their contracts.

With a project root, the existing source loader supplies project declarations.
The pass also activates for callers whose project dependency closure contains
throws annotations, even when the caller has none. Unrelated annotations do not
activate other files. Local module shadows are respected when collecting
dependencies; imported opens have conservative dependency sets because their
export shapes are not used by the dependency collector.

```sh
rescript-lint --project . src/Main.res
rescript-lint --project .
```

## Project Contracts

- `.resi` declarations define the public contract when present; otherwise
  implementation exports are indexed. Private implementation values are not
  leaked through interfaces. Interface-only modules are supported.
- Direct calls, simple value/module aliases, opens/includes and nested modules
  preserve imported contracts. Nested signature modules, signature opens,
  inline signature includes and `include module type of KnownModule` are
  supported in project mode.
- Declaration resolution iterates to a bounded fixed point so source discovery
  order does not change resolved aliases. Unresolved cycles fail explicitly
  when their annotated metadata or referenced contracts cannot be resolved.
- Exception identity is based on declarations, not spelling. Matching public
  exception paths in an implementation/interface form explicit identity
  equivalence classes, including transitive rebind aliases. Private and earlier
  shadowed exception declarations are not merged just because names match.
- Indexing does not analyze provider function bodies. Each requested file is
  checked in its own execution context; an unsaved current source replaces its
  saved project unit. Other buffers are read from disk, not a multi-buffer LSP
  snapshot.
- Malformed or unsupported required declaration metadata is reported with the
  provider filename and source range. Intermediate unresolved aliases are not
  reported before the final resolution pass. Disabled throws analysis does not
  construct or validate a throws index.
- Exported initializers cannot hide known annotated functions in aggregates,
  higher-order arguments or partial applications. These escapes and unresolved
  qualified aliases fail explicitly; ordinary initializer call effects do not
  become findings in importing callers.

Interface contracts govern imported references. Implementation-local calls keep
their implementation declarations; an interface annotation is not silently
copied onto a differently annotated or unannotated local function body. Bodies
are still not checked for conformance to their declared exception inventories.

This index uses current source, not `.cmt` artifacts, so no compiler build or
artifact freshness requirement is introduced for throws checks. It loads only
the configured project's source set, not dependency packages or standard-library
throws contracts by default. The explicit runtime adapter below adds a versioned
contract inventory. In an active file, unresolved qualified APIs still cause
explicit analysis errors. Unknown unqualified effects and hidden
promise results remain outside the guarantee.

## Pinned Runtime Adapter

```sh
rescript-lint --throws-runtime rescript-12.3.1 src/Main.res
rescript-lint --project . --throws-runtime rescript-12.3.1
```

The equivalent configuration is `"throwsRuntime": "rescript-12.3.1"`; `null`
removes the adapter. CLI/configuration settings apply in order. This is an
explicit compiler-version selection, not automatic installed-version detection.
It works with standalone files and project, fix, watch and LSP modes.

Selecting the adapter activates throws analysis for **every requested file**,
even without local annotations. Disabling `no-unhandled-throws` still bypasses
the pass. Without the adapter, existing activation is unchanged.

The adapter imports public runtime value/module shapes and these nine verified
contracts under `JSON`, `Stdlib.JSON` and `Stdlib_JSON`:

- `parseOrThrow`, `parseExn`, `parseExnWithReviver`.
- `stringifyAny`, `stringifyAnyWithIndent`, `stringifyAnyWithReplacer`,
  `stringifyAnyWithReplacerAndIndent`, `stringifyAnyWithFilter`, and
  `stringifyAnyWithFilterAndIndent`.

These are bare implementation `@throws`/`@raises` annotations, so they require an
unguarded catch-all, not just `JsExn(_)`. Public `.resi` declarations omit the
annotations; this versioned adapter deliberately imports the matching synchronous
external contracts. Tests verify their annotations, public types and FFI bindings
against the pinned sources. Project interfaces retain their existing precedence.

Known aliases/opens preserve contracts, and project/local module declarations
shadow runtime names. Opaque runtime module shapes remain unavailable and fail
explicitly when used; they are not treated as empty known modules. Private
implementation helpers are not exposed. Runtime exception-constructor aliases
are not added beyond the existing builtin exception identities.

Other runtime exports have **no declared contract in this adapter**, not a proof
of safety. In particular, this does not infer effects from `throw`, names such as
`getOrThrow`, documentation, callbacks, or shared JavaScript FFI names. Legacy
`Js.Json` remains distinct from `JSON`. Dependency packages are not discovered.
Unsupported active operations, including `await` and annotated-function escapes,
still return analysis errors even in files without their own annotations.

Within an active file, it tracks:

- Synchronous annotated function bindings and directly typed external/interface declarations.
- Named exception lists, repeated annotations, and bare annotations requiring a catch-all.
- Simple function aliases, sequential/recursive value bindings, and lexical value shadowing.
- Same-file module structures, nested modules, module aliases, opens, and includes.
- Local exception constructors and exception aliases. Declarations have identities, not just spellings; shadowing an exception does not change an existing function's contract.
- Direct and piped calls, including arguments, callbacks, local module initializers, and default parameters.
- Try/catch and switch exception patterns, scoped to the expressions they actually protect.

The existing analyzer escape `@doesNotThrow` has no effect. Annotating a caller also does not handle its calls. There is no automatic fix.

```rescript
exception Missing
exception Invalid(string)

@throws([Missing, Invalid])
let read = () => 0

// Both handling forms discharge the declared contract.
let caught = try Ok(read()) catch {
| Missing => Error(#Missing)
| Invalid(_) => Error(#Invalid)
}

let matched = switch read() {
| value => Ok(value)
| exception Missing | exception Invalid(_) => Error(#Failed)
}
```

`Invalid("specific value")` does not cover every `Invalid` exception. Neither does a guarded arm without an unguarded fallback. Matching `Ok`/`Error` alone does not catch evaluation failures. A handler surrounding creation of a callback does not protect the callback's later execution. Nested enclosing handlers in the same function may jointly cover the declared exceptions.

Bare annotations are useful for bindings without a concrete exception inventory:

```rescript
@throws @val external read: unit => int = "read"

let value = try read() catch {
| _ => 0
}
```

The examples are parser fixtures, not a promise that a particular JavaScript binding exists. Function bodies are not checked against their declared exception lists.

## Failure modes

An uncovered known call produces `no-unhandled-throws`, at the callee identifier, with the missing exception names. This is a lint error and exits with code `1`.

Unsupported analysis in an active file produces `throws-analysis` and exits with code `2`. The affected file returns analysis errors instead of partial lint findings; other input files continue to run. Examples include:

- Malformed annotation payloads, strings/computed exception values, or unresolved exception identities.
- Unresolved qualified values/modules, including dependency and standard-library modules whose declarations have not been loaded. Even a harmless unresolved qualified value is conservatively rejected because its callable contract is unknown.
- Passing an annotated function to an arbitrary higher-order function, returning/storing it in an aggregate, or explicit partial application. Simple named aliases remain supported.
- Annotated async functions, `await`, and directly promise-returning external/interface types.
- Annotated aliases or nonfunction bindings, and annotations attached to expressions, statements, or unsupported declaration positions.
- Constrained/functor/recursive/unpacked modules, named module types, extensible variant declarations, and interface constructs outside the supported declaration forms. Nested signature modules remain unsupported without project mode.

Ordinary helpers without annotations do not gain inferred throwing contracts. Unknown unqualified calls, implicit standard-library opens, indirect calls, arbitrary type aliases, returned-function effects, and hidden promise results are not resolved. In particular, this source-only pass cannot prove that an apparently synchronous function does not return a promise through an alias. The async checks reject recognizable unsupported syntax; they are not a promise-rejection analysis.

Handler matching is conservative. Wildcards, bound variables, aliases/type constraints around supported patterns, and tuple payloads containing only irrefutable subpatterns are recognized. Record payload patterns and collectively exhaustive literal alternatives are not proved exhaustive. Exception constructor identity is tracked for local declarations and the predefined exception names in the pinned compiler. Matching is not a substitute for ReScript type checking.

An immediate rethrow currently counts as handling the original call. Whether to require meaningful recovery remains a policy question; the rule does not inspect recovery quality or infer direct `throw` effects.

## Implementation

- `Throws_annotation`: structured AST decoding of supported annotation payloads. Unknown payloads return typed errors.
- `Throws_scope`: immutable lexical environments for value contracts, module exports, and exception identities. Module exports contain only their own declarations/includes, not inherited outer names.
- `Throws_handler`: pure conservative pattern-coverage computation. Handler sets combine only within one execution context.
- `No_unhandled_throws`: contextual traversal, unsupported-analysis reporting, and callee diagnostics.
- `Throws_dependencies`: lexical project dependency collection, including throws
  annotations, module aliases, types, and exception patterns, with local shadows.
- `Throws_project`: `.resi`-first declaration index, dependency-scoped activation,
  fixed-point resolution and implementation/interface exception identity pairing.
- `Throws_runtime`: opt-in pinned public runtime scope and nine verified JSON
  contracts. Upstream annotation/type/FFI parity is checked by the test suite.
- `Lint_error.Analysis_errors`: nonempty analysis diagnostics, separate from parse failures. `Linter` merges successful throws findings with other enabled rules before suppression auditing.

Function traversal consumes the parser's multi-parameter `Pexp_fun` chain using the outer arity, then treats any returned function as a fresh execution context. Exception identities are captured when an annotation is resolved. Compiler iterator accumulators remain local; no AST mutation or new production dependency was introduced.

## Research and next step

The [official exception-analysis documentation](https://rescript-lang.org/docs/manual/editor-plugins/#exception-analysis) explains propagation annotations and the existing analyzer's suppression behavior. This linter intentionally requires handling instead of propagation. The parser-backed tests verify annotations on bindings, interfaces, and externals, plus both [exception-switch patterns](https://rescript-lang.org/docs/manual/pattern-matching-destructuring/#match-on-exceptions) and try/catch.

The pinned runtime's `packages/@rescript/runtime/Stdlib_JSON.res` contains bare `@throws` and `@raises` externals. Named/multiple exception annotations occur in `tests/analysis_tests/tests-reanalyze/deadcode/src/exception/Exn.res`. The implementation was informed by these real declarations, not only invented examples.

The pinned `analysis/reanalyze/src/Exception.ml` consumes typed trees through `processCmt`, collects declarations/call events, and merges per-file value tables before checking. Its annotation decoder accepts additional historical forms that this first slice rejects explicitly. Its metadata-driven architecture provides the next integration direction; its implementation was not copied.

Project discovery, interface precedence and cross-file declaration identity are
now implemented for the bounded forms above. The optional pinned JSON runtime
adapter is also implemented. Next steps are dependency-package contracts,
additional module/type forms, and verified compiler metadata for cases
that source declarations cannot prove. The unrelated unused-export rule's
Reanalyze adapter does not establish typed-artifact compatibility for throws.
Work and verification: [project throws log](RULE_WORK_PROJECT_THROWS.md).
Runtime adapter: [work log](RULE_WORK_THROWS_RUNTIME.md).
