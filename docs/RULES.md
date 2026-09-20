# Initial Rules

Rule contracts, updated 2026-09-19. The initial syntax-only `no-console`, `no-object-magic`, and `no-unsafe` subsets are implemented and tested. Hooks and exception-handling rules remain specifications, not compiler-verified fixtures.

## Delivery order

1. `no-console`: first parser-to-diagnostic vertical slice.
2. `no-object-magic` and `no-unsafe`: share API identification with distinct diagnostics.
3. `react/rules-of-hooks`: intentionally limited placement checks.
4. `no-unhandled-throws`: explicit handling backed by annotation lookup and exception matching.

Prototype direct references first. Test pipes, local opens, module/value aliases, and shadowing before claiming complete API identification. Document supported ReScript versions and resolution limits. Do not silently treat unavailable semantic information as proof that a file is clean.

## no-console

Flag use of the target version's standard console APIs. Inventory `Console` and supported legacy logging APIs when the compiler version is selected. Include references passed as values so aliasing is not an obvious escape.

Acceptance cases: direct and piped logging; an aliased logging function; unrelated local symbols with the same name; console-like text in strings/comments. Custom external bindings and raw JavaScript require separate identification work and are not covered by matching standard APIs alone.

### Implemented subset (ReScript 12.3.1)

- Recognizes the pinned runtime's console members under `Console`, `Stdlib.Console`, `Stdlib_Console`, `Js.Console`, and `Js_console`, plus legacy `Js.log`, `log2`, `log3`, `log4`, and `logMany`.
- Reports qualified value references, not just calls. A value alias is flagged where it captures the console function; later calls through the alias are not reported again.
- Supports nested expressions, pipes, callbacks, and template interpolation; excludes literal text, comments, and annotation payloads.
- Tracks lexical shadowing from ordinary/recursive module bindings, block-local modules, and module-functor parameters. Bindings inside nested modules do not leak outward.
- Keeps findings in source order, with the qualified identifier's range. Invalid source yields syntax errors instead of partial lint results.

This is not symbol resolution. `module Log = Console; Log.log(1)` and `open Console; log(1)` are not identified. Opens/includes, unpacked module patterns, module-type functors, and cross-file modules can hide or change symbol identity, causing missed findings or false positives. For example, a project-defined `Console` module is indistinguishable from the standard module without project information. These limitations are deferred work, not a guarantee that an unreported file has no console effects. No type checking is performed.

Do not automatically remove calls: evaluating their arguments may have side effects.

## no-object-magic

Ban the unchecked cast API, including calls, value aliases, and passing it to another function. Report at the reference and suggest a validated conversion or precise type modeling. No automatic fix.

### Implemented subset (ReScript 12.3.1)

The runtime inspection corrected the original spelling: the standard cast is **`Obj.magic`**, not `Object.magic`. The rule retains its planned `no-object-magic` ID. `Stdlib.Object` contains JavaScript object helpers, and `Js.Obj` is a different module.

- Flags `Obj.magic` and the equivalent runtime exports `Primitive_object.magic` and `Primitive_object_extern.magic`.
- Reports value references, pipes, callbacks, and nested calls. A value alias is reported where it captures the cast; uses of that alias are not reported again.
- A surrounding try/catch or exception switch does not exempt an unchecked cast.
- Uses the same shared traversal, lexical module-shadow tracking, source ranges, and source ordering as `no-console`.
- Leaves unrelated `magic` functions, literal text, comments, and annotation payloads alone. Syntax errors prevent linting the file.

The inventory is grounded in the pinned runtime's `Obj.res`, `Primitive_object_extern.res`, and the re-export in `Primitive_object.res`. Unsupported spellings such as `Object.magic`, `Stdlib.Obj.magic`, and `Js.Obj.magic` are not treated as standard casts. The compiler is responsible for rejecting nonexistent APIs; this linter does not type-check them.

Module aliases and opens are still unresolved: `module Cast = Obj; Cast.magic(1)` and `open Obj; magic(1)` are not detected. Project-defined modules may produce false positives. Custom `%identity` externals and other unsafe conversion APIs are not part of this rule. These limits match the first `no-console` implementation and must be addressed before claiming comprehensive enforcement.

## no-unsafe

Unsafe APIs are banned regardless of their argument or surrounding handler. In particular, both `Option.getUnsafe(None)` and `Option.getUnsafe(Some(value))` are violations. No constant-value or proven-safe exemptions.

Use an explicit, versioned inventory of unsafe standard-library APIs, including the applicable `getUnsafe` functions. Configurable additions for project libraries remain planned. A function's spelling alone is insufficient evidence that it is the standard API. Decide separately whether to offer a broad name-based policy for custom functions.

Acceptance cases: known-present and absent arguments; dynamic arguments; calls inside try/catch and exception switches; aliases and pipes. Safe alternatives such as pattern matching on an option should pass.

This policy is distinct from exception handling: catching exceptions does not make a banned unsafe call acceptable. The [Option documentation](https://rescript-lang.org/docs/manual/api/stdlib/option/) distinguishes `getUnsafe`, which can return an invalid `undefined`, from `getOrThrow`, which throws.

### Implemented subset (ReScript 12.3.1)

- Flags the modern standard-library APIs, legacy `Js` APIs (including typed arrays), and `Belt` APIs listed in [UNSAFE_APIS.md](UNSAFE_APIS.md). The inventory follows exported interfaces; private implementation helpers are excluded.
- Flags qualified references, including calls, pipes, callbacks, and capturing an API as a value alias. Argument values, proven-present branches, and surrounding exception handlers do not grant exemptions.
- Reports at the reference and recommends a checked API or explicit pattern matching. No automatic fix is attempted.
- Shares lexical module-shadow tracking and diagnostic ordering with the other banned-API rules. Comments, strings, annotation payloads, and unrelated names are not flagged.
- Tests parse the pinned runtime sources/interfaces to independently check the selected modules' unsafe-named exports and ensure their other exports are not banned by this rule.

Module aliases, opens, and project-defined top-level modules retain the shared resolution limitations. For example, `module O = Option; O.getUnsafe(None)` and `open Option; getUnsafe(None)` are not detected yet. Custom unsafe bindings, unqualified globals, and APIs outside the explicit inventory are not covered. A nonfinding is not proof of safety. `Option.getOrThrow` belongs to the future exception-handling policy and is not banned here.

## react/rules-of-hooks

The first version checks recognizable hook calls within source-level `@react.component` functions and custom hooks. Use an explicit hook naming convention, initially `use` followed by an uppercase letter or digit, and recognize qualified calls. Avoid classifying names such as `user` as hooks.

Initial errors:

- Ordinary hooks inside conditional branches, switch arms, short-circuit right operands, or loops.
- Ordinary hooks inside callbacks or event handlers rather than directly in a component/custom-hook body.
- Ordinary hooks at module scope or in ordinary functions.
- Ordinary hooks in try bodies or handlers.

Initial passing cases: unconditional hooks in components/custom hooks, hooks after a completed conditional whose branches rejoin, and a separately defined nested custom hook with valid placement in its own body. Track each function's context separately.

Handle React's special `use` API separately if exposed by the selected bindings: it permits conditional and loop calls, but still has context and exception-handling restrictions. Verify those against the selected React version.

Defer exhaustive dependency arrays, full path analysis, higher-order hook factories, and general alias/data-flow inference. Document these limitations; basic useful checks are an acceptable first release.

Use the [official rule specification](https://react.dev/reference/eslint-plugin-react-hooks/lints/rules-of-hooks) and [rule implementation](https://github.com/facebook/react/blob/main/packages/eslint-plugin-react-hooks/src/rules/RulesOfHooks.ts) as references. The implementation's naming checks, per-function context, cycle detection, and code-path counting suggest how to expand coverage later; an ESLint rule cannot directly consume the ReScript AST.

## no-unhandled-throws

A call to a function declared with `@throws` must have applicable handling for every declared exception. Violations are lint errors and cause a failing CLI exit. Adding `@throws` to the caller does not count as handling. Existing analyzer escape annotations such as `@doesNotThrow` do not satisfy this rule either.

Recognize legacy `@raises` with the same handling requirement. ReScript deprecated `@raises` in favor of `@throws` in 12.0.0-beta.14; use `@throws` in examples and messages.

Recognize both ReScript handling forms. Given a function `read` annotated with `@throws(Not_found)`, these are intended passing examples:

```rescript
let matched = switch read() {
| value => Ok(value)
| exception Not_found => Error(#Missing)
}

let caught = try {
  Ok(read())
} catch {
| Not_found => Error(#Missing)
}
```

ReScript documents [exception patterns in switches](https://rescript-lang.org/docs/manual/pattern-matching-destructuring/#match-on-exceptions) and [try/catch](https://rescript-lang.org/docs/manual/exception/). Matching `Ok`/`Error` values alone does not catch an exception thrown while producing that value.

### Handler scope and coverage

- Switch exception arms protect evaluation of the switched expression, not calls in result arms or handler bodies.
- Try/catch protects evaluation of its body, not calls in its catch handlers.
- A handler around creation of a function does not protect that function's later execution. Start a fresh handling context for each function body.
- Handling the wrong exception, only some declared exceptions, or only selected payloads is insufficient.
- A guarded pattern is not exhaustive unless a later unguarded pattern provides the missing coverage. Initially use conservative matching rather than trying to prove guards true.
- Recognize unguarded wildcard/bound-variable catch-all exception patterns and constructor patterns covering every payload.
- Nested enclosing handlers may jointly cover the declared exceptions when they are in the same execution context.
- A promise returned inside try/catch is not thereby protected against later rejection. Track supported `await` handling explicitly; general promise-chain analysis is a later capability. Unsupported async analysis must be visible.

### Required acceptance cases

| Scenario | Expected result |
| --- | --- |
| Annotated call with no handler | Error at call site |
| Caller repeats the callee's `@throws` annotation | Still an error |
| Switch exception arms cover all declared exceptions | Pass |
| Try/catch covers all declared exceptions | Pass |
| Switch only matches ordinary result values | Error |
| Handler catches another exception or an incomplete set | Error naming uncovered exceptions |
| Matching handler has a guard without exhaustive fallback | Error |
| Handler covers only one payload of a declared constructor | Error |
| Unguarded exception catch-all covers the call | Pass |
| Call appears inside a switch result arm or catch body | Needs its own applicable enclosing handler |
| Deferred callback is created under a handler | Handler does not cover callback execution |
| Annotated callee comes from another file/interface/external | Same contract after resolving its declaration |
| Required metadata is missing, stale, or incompatible | Analysis failure, not a clean lint result |

Open policy detail: whether a handler that immediately rethrows should itself fail this rule. Presence of a handler cannot establish meaningful recovery. Define that separately from the confirmed requirement that unhandled annotated calls fail.

### Existing tooling and implementation ideas

ReScript's [documented exception analyzer](https://rescript-lang.org/docs/manual/editor-plugins/#exception-analysis) tracks exceptions and allows annotations to move the obligation to callers. This project's rule requires local handling instead, so merely escalating those analyzer warnings to errors would not implement the requested policy.

Inspected the ReScript monorepo on 2026-09-19, with master resolving to `e35c08a86cd077bf53d938fbe7a5291fed49da00`:

- [exception.ml](https://github.com/rescript-lang/rescript/blob/e35c08a86cd077bf53d938fbe7a5291fed49da00/analysis/reanalyze/src/exception.ml): typed-tree traversal, annotation decoding, callee lookup, and nested call/throw/catch events. Its separate traversal of protected expressions and case bodies is useful. The inspected pattern helper collects constructor names without checking guards or payload coverage; do not copy that behavior as our coverage proof.
- [exn_lib.ml](https://github.com/rescript-lang/rescript/blob/e35c08a86cd077bf53d938fbe7a5291fed49da00/analysis/reanalyze/src/exn_lib.ml): modeled library exceptions suggest a registry for APIs lacking usable annotations. Verify any adopted entries against our supported library versions.
- [Reanalyze README](https://github.com/rescript-lang/rescript/blob/e35c08a86cd077bf53d938fbe7a5291fed49da00/analysis/reanalyze/README.md): compiler-artifact processing suggests a semantic integration path, whose metadata compatibility and build requirements must be proven in the spike.

First investigate annotation preservation in `.res`, `.resi`, and external declarations, plus module aliases and symbol identity. Then decide whether source indexing suffices for an initial subset or compatible compiler artifacts are required. No new dependency or copied implementation is selected by this research.
