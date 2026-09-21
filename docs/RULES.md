# Rule Contracts

Rule contracts, updated 2026-09-21. The registry contains 105 implemented rule
subsets: twelve defaults and 93 opt-in rules. The syntax additions are documented
in [SYNTAX_RULES.md](SYNTAX_RULES.md); the remaining 83 rules and their required
adapters, configuration, and analysis limits are in [EXTENDED_RULES.md](EXTENDED_RULES.md).
`no-unhandled-throws` supports source-local and configured-project declaration
contracts; full whole-program effects remain outside its guarantee. Rule fixtures are parsed, not
type-checked.

## Delivery order

1. `no-console`: first parser-to-diagnostic vertical slice.
2. `no-object-magic` and `no-unsafe`: share API identification with distinct diagnostics.
3. `react/rules-of-hooks`: intentionally limited placement checks.
4. `no-unhandled-throws`: explicit handling backed by annotation lookup and exception matching.
5. `blank-lines`: formatter-compatible spacing and the first opt-in autofix command.
6. `no-constant-condition`, `no-constant-binary-expression`,
   `no-duplicate-condition`, and `no-identical-branches`: a shared conservative
   control-flow pass.
7. Twelve further syntax checks: exception/debugger rules, optional expression
   simplifications, and optional size/comment/empty-code policies. See
   [the syntax rule reference](SYNTAX_RULES.md).

## blank-lines

Requires separator lines after externals and pipe statements/bindings, before
annotated value bindings, and around switch statements/bindings. Supports `.res`,
`.resi`, nested statement blocks, and JSX siblings. Enabled by default;
`--fix` inserts minimal newlines and verifies the result against the pinned
ReScript formatter before writing. See [BLANK_LINES.md](BLANK_LINES.md) for
the precise boundaries, comment behavior, file safety, and regression contract.

Prototype direct references first. Test pipes, local opens, module/value aliases, and shadowing before claiming complete API identification. Document supported ReScript versions and resolution limits. Do not silently treat unavailable semantic information as proof that a file is clean.

## Control-flow rules

The first four rules from the candidate plan now share one syntax traversal:

- `no-constant-condition` reports literal or safely folded boolean conditions
  in `if`, `while`, and switch guards.
- `no-constant-binary-expression` reports boolean and literal comparison
  expressions whose result is fixed. It can report alongside
  `no-constant-condition` when the same expression is used as a condition.
- `no-duplicate-condition` reports repeated stable conditions within one
  `if`/`else if` chain or switch guards with identical patterns. Function calls,
  field reads, and other expressions that may change between evaluations are
  not assumed stable; an intervening unstable test resets duplicate tracking.
- `no-identical-branches` reports adjacent `if`/`else if`/`else` bodies or
  switch result arms with structurally identical ASTs. Switch patterns must be
  identical or their results must not reference either arm's pattern bindings.
  Comments and source locations do not make otherwise identical branches
  distinct; attributes do.

Constant evaluation is deliberately narrow: boolean literals, `&&`, `||`, and
literal `==`, `!=`, `===`, `!==`, `<`, `<=`, `>`, and `>=` comparisons. It does
not infer bindings, types, mutable state, function purity, or reachability. The
folding excludes escaped strings, non-ASCII string ordering, and integers
outside the signed 32-bit domain rather than assuming OCaml runtime semantics
match JavaScript for those cases. The
rules emit source-ordered diagnostics and no fixes. Any future fix must prove
that it preserves the evaluation of effectful operands and conditions.

## Shared API Resolution

The three banned-API rules share the lexical semantic walker and a generated
public export-shape snapshot of the pinned ReScript 12.3.1 runtime. Same-file
module aliases/chains, nested modules, known opens/includes and inline module
constraints preserve resolved API identity. Value/function/case pattern bindings
shadow opened values. Module captures retain their original target after a later
shadow, and includes retain the scope at their declaration, not a later scope.
Nested modules export their declarations/includes, not ambient or opened names.

Messages name the canonical runtime API; diagnostic ranges cover the actual
reference, including short opened names and aliases. Capturing an API in a value
binding is reported there only; later references to that captured value are not
reported again. No automatic fixes are offered.

With a configured project, discovered module names shadow runtime roots and
available public module aliases/signatures participate in resolution. Project
value-alias bodies are not followed. Without project information, a same-named
module in another file cannot be distinguished from a runtime root.

Unknown opens/includes conservatively invalidate earlier visible bindings rather
than guessing their exports. This can suppress findings for otherwise familiar
names. Functor results, unpacked module contents, named module constraints and
unavailable dependency metadata remain unknown. Custom FFI/raw JavaScript effects
and APIs outside each rule's explicit inventory are not inferred. This is bounded
declaration resolution, not type checking or proof that unreported code is safe.

## no-console

Flag use of the target version's standard console APIs. Inventory `Console` and supported legacy logging APIs when the compiler version is selected. Include references passed as values so aliasing is not an obvious escape.

Acceptance cases: direct and piped logging; an aliased logging function; unrelated local symbols with the same name; console-like text in strings/comments. Custom external bindings and raw JavaScript require separate identification work and are not covered by matching standard APIs alone.

### Implemented subset (ReScript 12.3.1)

- Recognizes the pinned runtime's console members under `Console`, `Stdlib.Console`, `Stdlib_Console`, `Js.Console`, and `Js_console`, plus legacy `Js.log`, `log2`, `log3`, `log4`, and `logMany`.
- Reports resolved value references, not just calls. A value alias is flagged where it captures the console function; later calls through the alias are not reported again.
- Supports nested expressions, pipes, callbacks, and template interpolation; excludes literal text, comments, and annotation payloads.
- Tracks lexical shadowing from ordinary/recursive module bindings, block-local modules, and module-functor parameters. Bindings inside nested modules do not leak outward.
- Keeps findings in source order, with the source identifier's range. Invalid source yields syntax errors instead of partial lint results.

`module Log = Console; Log.log(1)` and `open Console; log(1)` are detected.
Safe names from later known opens shadow correctly: `open Console; open Js.Math;
log(1.0)` does not report console use. See shared resolution boundaries above.

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

The inventory is grounded in the pinned runtime's `Obj.res`, `Primitive_object_extern.res`, and the implementation re-export in `Primitive_object.res`. The latter's `.resi` hides `magic`; its spelling remains an explicit compatibility ban, separately from the public export snapshot. Unsupported spellings such as `Object.magic`, `Stdlib.Obj.magic`, and `Js.Obj.magic` are not treated as standard casts. The compiler is responsible for rejecting nonexistent APIs; this linter does not type-check them.

`module Cast = Obj; Cast.magic(1)` and `open Obj; magic(1)` are detected.
Custom `%identity` externals and other conversion APIs remain outside this rule;
the shared resolution boundaries above apply.

## no-unsafe

Unsafe APIs are banned regardless of their argument or surrounding handler. In particular, both `Option.getUnsafe(None)` and `Option.getUnsafe(Some(value))` are violations. No constant-value or proven-safe exemptions.

Use an explicit, versioned inventory of unsafe standard-library APIs, including the applicable `getUnsafe` functions. Configurable additions for project libraries remain planned. A function's spelling alone is insufficient evidence that it is the standard API. Decide separately whether to offer a broad name-based policy for custom functions.

Acceptance cases: known-present and absent arguments; dynamic arguments; calls inside try/catch and exception switches; aliases and pipes. Safe alternatives such as pattern matching on an option should pass.

This policy is distinct from exception handling: catching exceptions does not make a banned unsafe call acceptable. The [Option documentation](https://rescript-lang.org/docs/manual/api/stdlib/option/) distinguishes `getUnsafe`, which can return an invalid `undefined`, from `getOrThrow`, which throws.

### Implemented subset (ReScript 12.3.1)

- Flags the modern standard-library APIs, legacy `Js` APIs (including typed arrays), and `Belt` APIs listed in [UNSAFE_APIS.md](UNSAFE_APIS.md). The inventory follows exported interfaces; private implementation helpers are excluded.
- Flags resolved references, including calls, pipes, callbacks, and capturing an API as a value alias. Argument values, proven-present branches, and surrounding exception handlers do not grant exemptions.
- Reports at the reference and recommends a checked API or explicit pattern matching. No automatic fix is attempted.
- Shares lexical module-shadow tracking and diagnostic ordering with the other banned-API rules. Comments, strings, annotation payloads, and unrelated names are not flagged.
- Tests parse the pinned runtime sources/interfaces to independently check the selected modules' unsafe-named exports and ensure their other exports are not banned by this rule.

`module O = Option; O.getUnsafe(None)` and `open Option; getUnsafe(None)` are
detected. Custom unsafe bindings, unrelated unqualified globals and APIs outside
the explicit inventory are not covered. A nonfinding is not proof of safety.
`Option.getOrThrow` is a separate exception-handling concern and is not banned
here. The shared resolution boundaries above apply.

## react/rules-of-hooks

The first version checks recognizable hook calls within source-level `@react.component` functions and custom hooks. Use an explicit hook naming convention, initially `use` followed by an uppercase letter or digit, and recognize qualified calls. Avoid classifying names such as `user` as hooks.

Initial errors:

- Ordinary hooks inside conditional branches, switch arms, short-circuit right operands, or loops.
- Ordinary hooks inside callbacks or event handlers rather than directly in a component/custom-hook body.
- Ordinary hooks at module scope or in ordinary functions.
- Ordinary hooks in try bodies or handlers.

Initial passing cases: unconditional hooks in components/custom hooks, hooks after a completed conditional whose branches rejoin, and a separately defined nested custom hook with valid placement in its own body. Track each function's context separately.

Handle React's special `use` API separately: it permits conditional and loop calls, but still has context and exception-handling restrictions.

Defer exhaustive dependency arrays, full path analysis, higher-order hook factories, and general alias/data-flow inference. Document these limitations; basic useful checks are an acceptable first release.

Use the [official rule specification](https://react.dev/reference/eslint-plugin-react-hooks/lints/rules-of-hooks) and [rule implementation](https://github.com/facebook/react/blob/main/packages/eslint-plugin-react-hooks/src/rules/RulesOfHooks.ts) as references. The implementation's naming checks, per-function context, cycle detection, and code-path counting suggest how to expand coverage later; an ESLint rule cannot directly consume the ReScript AST.

### Implemented subset (ReScript 12.3.1 parser)

- Checks syntactic applications and direct/piped calls, with one diagnostic at the callee identifier. Merely referencing or passing a hook as a value is not a call.
- Uses `use[A-Z0-9]` as the naming convention, including qualified names such as `Hooks.useThing`. `user`, `useful`, and `use_thing` are not hooks. Unlike the banned-API rules, this is a naming policy, not a standard-library inventory.
- Recognizes bindings annotated `@react.component`, `@jsx.component`, or `@react.componentWithProps`, plus named custom-hook function bindings. An unannotated `make` is an ordinary function.
- Preserves component context through type constraints and direct `React.memo`/`React.forwardRef` wrappers on annotated bindings, including nested wrappers. Additional wrapper arguments, such as comparators, remain ordinary callbacks.
- Rejects ordinary hooks in conditional branches, switch guards/arms, short-circuit right operands, and loop bodies/while conditions. A normal condition, switch scrutinee, or for-loop bound evaluates in the enclosing context. A completed branch does not invalidate later hooks.
- Gives each actual function a fresh context; multiple parser parameter nodes still form one function. Callbacks, returned anonymous functions, and ordinary named functions are not hook bodies. Separately defined nested named custom hooks have their own valid context. Module initializers never inherit component context.
- Rejects hooks in async functions, default arguments, try bodies, and catch guards/arms. Conservatively treats an entire switch with any exception pattern as an exception-handling region, including its normal result arms.
- Treats exactly bare `use` and `React.use` as React's special API. They allow conditions, switch branches, short-circuit expressions, and loops, but not invalid function contexts, async functions, default arguments, or exception-handling regions. `Other.use` is not recognized as that API.
- Skips comments, literal text, and annotation payloads. JSX expressions are traversed, including event-handler callbacks. Invalid syntax stops all rule analysis. Diagnostics from all rules are merged in source order with UTF-8 byte ranges.

The current [React specification](https://react.dev/reference/eslint-plugin-react-hooks/lints/rules-of-hooks), checked 2026-09-20, informs placement and special-`use` behavior. No React binding package is installed or pinned here; the linter does not prove that a binding exists or that these examples type-check. Parser representation was verified against the pinned ReScript sources and fixtures, rather than inferred from JavaScript syntax.

This remains deliberately incomplete. There is no symbol/shadow resolution for hooks: a local non-React `useSomething` can be flagged, and a hook captured under a non-hook alias can escape detection. React namespace aliases and unannotated wrapper components are not inferred. Unknown higher-order wrappers, hook factories, destructured function bindings, explicit partial applications, and placeholder-generated functions are not modeled semantically; syntactic applications are checked conservatively and can produce false positives. The rule does not prove reachability, account for every throw/non-returning path, enforce dependency arrays, or detect hooks called indirectly by ordinary functions. It offers no automatic fix and is not a replacement for exhaustive React analysis.

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

### Implemented Declaration Subset

The parser preserves annotations on implementation bindings, external declarations, and interface values. The rule now enforces synchronous calls whose declarations can be resolved within the same source file, including lexical value shadowing, simple value aliases, local modules/module aliases, local opens/includes, and exception-constructor identity. Known incomplete analysis becomes `Lint_error.Analysis_errors` with `throws-analysis` diagnostics and exit code `2`; unhandled known calls are `no-unhandled-throws` lint errors with exit code `1`.

Supported annotations are bare `@throws`/`@raises`, a named exception, or a nonempty array/tuple of named exceptions. Repeated annotations are combined. Bare annotations describe unknown exceptions and require a catch-all. Unsupported payloads and unresolved exception identities fail analysis. Strings and computed exception values are deliberately unsupported rather than silently ignored.

Only unguarded whole-exception catch-alls or named constructor patterns with irrefutable payloads discharge an obligation. Nested enclosing handlers can jointly cover exceptions. Switch handlers protect the scrutinee, never their result arms, guards, or handler bodies; try handlers protect only the try body. Each actual function resets handler context, including callbacks and returned functions. A handler that rethrows currently counts as handling; recovery quality is not analyzed.

**Activation and limits:** without a root or runtime adapter, this pass activates only for local
annotations. A configured project also activates callers of annotated project
modules, using `.resi`-first exports, aliases and explicit exception declaration
identity pairing. Unrelated modules do not activate callers. Supported nested
signature modules, opens and includes are indexed with an imported scope.
`--throws-runtime rescript-12.3.1` explicitly activates every selected file and
imports nine verified bare JSON runtime contracts requiring catch-all handling.
Other runtime exports have no declared contract, not proof of no effects.
Dependency packages and compiler artifacts are not loaded. Unresolved
qualified references and unsupported known async/promise/escape/module forms fail
explicitly in active files; unknown unqualified effects are not inferred.
Implementation-local calls retain local declarations rather than inheriting
interface-only annotations. See [THROWS.md](THROWS.md) for the exact boundary.

### Existing tooling and implementation ideas

ReScript's [documented exception analyzer](https://rescript-lang.org/docs/manual/editor-plugins/#exception-analysis) tracks exceptions and allows annotations to move the obligation to callers. This project's rule requires local handling instead, so merely escalating those analyzer warnings to errors would not implement the requested policy.

Inspected the ReScript monorepo on 2026-09-19, with master resolving to `e35c08a86cd077bf53d938fbe7a5291fed49da00`:

- [exception.ml](https://github.com/rescript-lang/rescript/blob/e35c08a86cd077bf53d938fbe7a5291fed49da00/analysis/reanalyze/src/exception.ml): typed-tree traversal, annotation decoding, callee lookup, and nested call/throw/catch events. Its separate traversal of protected expressions and case bodies is useful. The inspected pattern helper collects constructor names without checking guards or payload coverage; do not copy that behavior as our coverage proof.
- [exn_lib.ml](https://github.com/rescript-lang/rescript/blob/e35c08a86cd077bf53d938fbe7a5291fed49da00/analysis/reanalyze/src/exn_lib.ml): modeled library exceptions suggest a registry for APIs lacking usable annotations. Verify any adopted entries against our supported library versions.
- [Reanalyze README](https://github.com/rescript-lang/rescript/blob/e35c08a86cd077bf53d938fbe7a5291fed49da00/analysis/reanalyze/README.md): compiler-artifact processing suggests a semantic integration path, whose metadata compatibility and build requirements must be proven in the spike.

The source-preservation spike and configured-project declaration index are covered
by parser-backed tests. More advanced effects and dependency contracts still need
additional metadata. No new dependency or copied analyzer implementation was introduced.
