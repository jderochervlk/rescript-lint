# Test Framework Rule Work Log

## Adapter Evidence

- Inspected the installed `rescript-vitest` 3.0.1 audit fixture at `/tmp/rescript-rule-compile-check/node_modules/rescript-vitest` and confirmed its package version and unnamespaced module configuration.
- Read the complete `Vitest.res`, `Vitest_Bindings.res`, `Vitest_Matchers.res`, and `Vitest_Assert.res` binding sources.
- Adapter recognition covers actual exported runners, `For`, `Todo`, `InSource`, lifecycle hooks, assertion entrypoints, and matcher modules. `EachType` is only a module type, so no nonexistent `Vitest.Each` API is recognized.
- Root owns explicit CLI activation (`--test-framework rescript-vitest-3`), rule registry/configuration, and integration. All twelve test rules remain opt-in.

## Implementation

- Added an immutable scope model for local values, module aliases, opens, includes, shadowing, local callback functions, constrained module exports, and explicit `@module("vitest")` FFI declarations.
- Added a traversal producing suite/test/assertion events; rule evaluation separates suite-local titles and hook ordering from conditional execution and assertion ownership.
- Local named callbacks and invoked helper functions preserve captured lexical scopes. Nested tests and hook callbacks do not satisfy their enclosing test's assertion requirement.
- Attribute payloads and interface declarations do not execute; unknown opens and opaque callback bodies are treated conservatively.

## Boundaries To Verify

- The AST supplies no project-wide metadata for arbitrary imported callbacks or module functor results. These do not become known framework identities through spelling alone.
- The maximum describe nesting defaults to five and is exposed as an explicit function argument for root configuration.
- Build/test and coverage are serialized by the parent agent after the first implementation batch is ready.
- First parent build exposed OCaml value-restriction inference in the generic map merge helper; eta-expanding the helper keeps value and module maps separately typed without weakening types.
- The pinned AST stores labeled-argument names as located strings; corrected option matching to use their text field.
- Follow-up review queued runtime `Vitest.skip`/`skipIf` recognition and try/catch assertion handling after the first twelve-rule fixture batch passes.
- Parent confirmed all 129 initial parser-driven cases passed after the two compile corrections.
- Grouped follow-up adds runtime skip APIs, protected/caught assertion diagnostics, and static scans of dormant function bodies. Dormant scans check source-local policy but do not invent runtime suite ownership or duplicate suite-local events.
- Added focused follow-up and FFI identity regressions, bringing the suite to 148 cases.
- Full compiled-example auditing exposed all twelve examples starting with a shared `open Prelude`; unknown-open conservatism obscured the verified adapter. Added optional project module signatures, tracking their actual exported names. Known unrelated opens now preserve bindings, while real exported collisions still shadow them.
- Project modules named Vitest override the dependency adapter; repository discovery excludes node_modules, so project signatures cannot accidentally replace the verified dependency with its own opaque exports. Added seven project-open/export regressions.
- Parent's serialized full suite passes all 155 cases. Coverage: Test_rules 96.90%, Test_scope 90.40%.
