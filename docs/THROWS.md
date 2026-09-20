# Source-Local Throws Analysis

Implemented and tested against the pinned ReScript 12.3.1 parser, 2026-09-20. This is the first exception-rule slice, not complete checked-exception support.

## What runs today

The pass activates when a parsed file contains `@throws` or legacy `@raises`. A file without either annotation is outside this pass, even when another file or a library declares that one of its callees throws. Explicit CLI file arguments are still analyzed independently; passing both an implementation and interface does not link their contracts.

Within an annotated file, it tracks:

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

Unsupported analysis in an annotated file produces `throws-analysis` and exits with code `2`. The affected file returns analysis errors instead of partial lint findings; other input files continue to run. Examples include:

- Malformed annotation payloads, strings/computed exception values, or unresolved exception identities.
- Unresolved qualified values/modules, including external project and standard-library modules whose declarations have not been loaded. Even a harmless unresolved qualified value is conservatively rejected because its callable contract is unknown.
- Passing an annotated function to an arbitrary higher-order function, returning/storing it in an aggregate, or explicit partial application. Simple named aliases remain supported.
- Annotated async functions, `await`, and directly promise-returning external/interface types.
- Annotated aliases or nonfunction bindings, and annotations attached to expressions, statements, or unsupported declaration positions.
- Constrained/functor/recursive/unpacked modules, module types, extensible variant declarations, and nested/interface module constructs requiring metadata not yet indexed.

Ordinary helpers without annotations do not gain inferred throwing contracts. Unknown unqualified calls, implicit standard-library opens, indirect calls, arbitrary type aliases, returned-function effects, and hidden promise results are not resolved. In particular, this source-only pass cannot prove that an apparently synchronous function does not return a promise through an alias. The async checks reject recognizable unsupported syntax; they are not a promise-rejection analysis.

Handler matching is conservative. Wildcards, bound variables, aliases/type constraints around supported patterns, and tuple payloads containing only irrefutable subpatterns are recognized. Record payload patterns and collectively exhaustive literal alternatives are not proved exhaustive. Exception constructor identity is tracked for local declarations and the predefined exception names in the pinned compiler. Matching is not a substitute for ReScript type checking.

An immediate rethrow currently counts as handling the original call. Whether to require meaningful recovery remains a policy question; the rule does not inspect recovery quality or infer direct `throw` effects.

## Implementation

- `Throws_annotation`: structured AST decoding of supported annotation payloads. Unknown payloads return typed errors.
- `Throws_scope`: immutable lexical environments for value contracts, module exports, and exception identities. Module exports contain only their own declarations/includes, not inherited outer names.
- `Throws_handler`: pure conservative pattern-coverage computation. Handler sets combine only within one execution context.
- `No_unhandled_throws`: contextual traversal, unsupported-analysis reporting, and callee diagnostics.
- `Lint_error.Analysis_errors`: nonempty analysis diagnostics, separate from parse failures. `Linter` merges successful throws findings with the four existing rule subsets.

Function traversal consumes the parser's multi-parameter `Pexp_fun` chain using the outer arity, then treats any returned function as a fresh execution context. Exception identities are captured when an annotation is resolved. Compiler iterator accumulators remain local; no AST mutation or new production dependency was introduced.

## Research and next step

The [official exception-analysis documentation](https://rescript-lang.org/docs/manual/editor-plugins/#exception-analysis) explains propagation annotations and the existing analyzer's suppression behavior. This linter intentionally requires handling instead of propagation. The parser-backed tests verify annotations on bindings, interfaces, and externals, plus both [exception-switch patterns](https://rescript-lang.org/docs/manual/pattern-matching-destructuring/#match-on-exceptions) and try/catch.

The pinned runtime's `packages/@rescript/runtime/Stdlib_JSON.res` contains bare `@throws` and `@raises` externals. Named/multiple exception annotations occur in `tests/analysis_tests/tests-reanalyze/deadcode/src/exception/Exn.res`. The implementation was informed by these real declarations, not only invented examples.

The pinned `analysis/reanalyze/src/Exception.ml` consumes typed trees through `processCmt`, collects declarations/call events, and merges per-file value tables before checking. Its annotation decoder accepts additional historical forms that this first slice rejects explicitly. Its metadata-driven architecture provides the next integration direction; its implementation was not copied.

Next, prove project discovery and a declaration index or compatible `.cmt`/`.cmti` reader. Establish interface precedence, dependency contracts, canonical cross-file symbol identity, and missing/stale artifact detection. The current build includes parser/compiler data types but does not establish artifact compatibility or load compiler metadata. Do not describe the current local pass as enforcing all annotated calls in a project until that work is verified.
