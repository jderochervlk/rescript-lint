# Throws Module Types

## Pinned Evidence

- `vendor/rescript/compiler/ml/typemod.ml:694` translates module types in their lexical environment. `Pmty_ident` is distinct from a module alias and uses the module-type namespace. `Pmty_signature` translates declarations; `Pmty_typeof` derives an existing module shape.
- `typemod.ml:1349` checks a constrained module body separately and wraps it with an explicit public module type. This supports separate body traversal and signature-authoritative public metadata, not inferred effects or implementation annotations leaking through the signature.
- Pinned positive syntax examples include `tests/tools_tests/src/DocExtractionRes.res:105`, `tests/tests/src/inner_define.res`, `tests/syntax_tests/data/printer/signature/modtype.resi`, and `tests/syntax_tests/data/printer/modType/moduleTypeOf.res`. Parser fixtures alone do not replace compiler verification.
- Existing `Throws_dependencies` already distinguishes module-type bindings and follows qualified aliases, includes and constraints. The missing capability was the throws contract scope/resolver, not filesystem discovery.

## Bounded Contract

- Resolve named module-type declarations and aliases in a separate immutable namespace. Templates capture already-resolved lexical contracts; later opens, shadowing or same-spelled module declarations do not change those captures.
- Preserve explicitly exported module types through module aliases, includes, opens, project interfaces and package scopes. Opened/ambient declarations do not become exports. Qualified resolution observes interface visibility.
- Support `Pmty_ident` in signature modules/includes and explicit module constraints. Inline signatures and known `module type of` shapes remain available. Constraints expose the explicit signature's annotations, including intentionally unannotated public values; hidden implementation annotations are not promoted.
- Analyze constrained implementation bodies when checking that source, using their own lexical declarations. Provider indexing only consumes the constraint signature; hidden initializer metadata and annotation placements are not validated as public contracts.
- Reject templates and constraints exporting exception constructors, including nested constructors and `module type of`/include-derived constructors. A shared signature declaration is not a shared runtime exception identity: `A:S` and `B:S` must not let `B.E` incorrectly handle `A.run`. Fresh constructor instantiation is deferred as one explicit limitation, not approximated with shared source locations.
- Templates may refer to previously declared external/lexical exceptions or use bare annotations. Existing project implementation/interface equivalence remapping also traverses stored module types.
- Abstract/unresolved/cyclic module types, functor types and inferred results, type substitutions, recursive/unpacked modules and other unsupported shapes remain explicit analysis failures. Provider indexing can consume an explicit public signature without inspecting a hidden functor/unpack implementation; checking that implementation source still rejects unsupported operations. This is declaration enforcement, not functor-result inference. Existing source-local nested inline interface restrictions are unchanged; named signatures gain the targeted supported path.
- The lexical dependency collector still conservatively visits hidden constrained implementation references. Indirect dependencies discovered there may require valid metadata, even though the constrained provider's direct hidden metadata is not indexed. Narrowing dependency collection is outside this slice.

## API And Files

- `Throws_scope`: add `module_type` lookup and `add_module_type`; overlay, opaque shadowing and exception remapping include the new namespace.
- `No_unhandled_throws`: add named declaration resolution, checked reusable signatures, and constraint traversal/projection. Public `check`/`exports` APIs remain unchanged.
- `test/throws_module_types_test.ml`: focused public Linter tests with exact callee/rule/message/range checks, plus configured-project metadata and activation cases. Existing two tests asserting all module-type declarations unsupported now assert successful supported behavior.

## Test Matrix

- Bare/named contracts, catch-all and insufficient handlers, lexical exception captures, module-type aliases/chains, module/value namespace distinction, opens/includes, qualified aliases, ambient export isolation.
- Inline/named/nested constraints, signature-authoritative removal/addition of annotations, private value visibility, implementation body calls, provider hidden metadata, pre-existing exception references.
- Interface precedence, nested interface named signatures, reverse dependency aliases, public/hidden module types, dependency-scoped activation and `.res`/`.resi` exception remapping.
- Explicit failures for fresh exception templates (two-module identity stress case), nested/existing-export exception templates, unknown/abstract/cyclic module types, substitutions and functors; inactive default unchanged.

## Verification Log

- Initial work was read-only research. Parent authorized this bounded extension after the fresh-constructor identity risk was identified.
- Initial 46 new public Linter cases passed in the parent's full test run. The sole failure was an older test that expected all constrained modules to remain unsupported; updated it to assert signature authority at a subsequent public call.
- Added two grouped regressions contrasting a provider's explicitly declared contract around a hidden functor with active-source rejection of that functor body. Total 48 new cases; final verification pending. No new production dependencies, configuration switches or filesystem discovery behavior.
- Parent independently compiled four modules with actual ReScript 12.3.1 at `/tmp/rescript-module-types.E2ZNZ5`. A provider declares `Failure`, a named `Contract` with `@throws(Failure)`, and `Api: Contract`. An unhandled `Provider.Api.run` produced one JSON finding and exit 1; a matching `Provider.Failure` catch produced no findings and exit 0. Compiler output contained only the known `raise` deprecation warning.
- Parent's full gates passed with the initial 48 cases: 95.55% overall (7403/7748), `No_unhandled_throws` 98.48%, `Throws_scope` 99.07%. Independent policy review found no defects.
- Added three targeted review regressions, without production edits: alias capture before a nested type shadow; an inner abstract type must not resolve to an outer template; and module types exported through dependency packages must follow cross-package implementation/interface exception remapping. Total 51 cases; final rerun pending.
- Grouped follow-up rather than per-failure widening: record any parser fixture mismatch, unsupported shape or coverage gaps here after the first complete focused run. Fresh exception instantiation remains deferred regardless of unrelated test failures.
- Final rerun passed all 51 cases in `make check coverage`, including the three independent-review regressions. Overall coverage remains 95.55% (7403/7748). User then requested a pause; no further implementation or commit/push occurred. See [PAUSE_STATE.md](PAUSE_STATE.md).
