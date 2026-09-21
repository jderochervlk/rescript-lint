# Project Throws Work Log

## Scope

Continue the next item in the plan after the 105-rule catalog expansion: resolve
project-local public throws contracts for callers without their own annotations.
Keep the existing source-only path and failure behavior when no project is
configured. No new dependency, commit or publication is needed.

## Work

- Read the existing analyzer, immutable exception scope, handler/annotation
  modules, project loader, plan, handoff and previous verification logs.
- Applied functional-code-style and writing-functions skills.
- Delegated integration tests and lexical dependency analysis to independent
  agents, with serialized Dune verification owned by the main agent.
- Added declaration-only export indexing to the existing throws traversal;
  indexing does not execute or inspect ordinary function bodies.
- Added `.resi`-first project metadata, bounded fixed-point dependency resolution,
  dependency-scoped activation and provider-located metadata diagnostics.
- Added explicit exception identity equivalence classes for matching exported
  implementation/interface declarations. Rebound aliases are unified transitively;
  unrelated same-spelled constructors remain distinct.
- Integrated project analysis at the existing project-load boundary, avoiding a
  second project read and preserving rule selection and suppression ordering.
- Initial implementation awaits the grouped integration test run. Review notes:
  do not leak ambient scope through signature exports, do not visit provider
  bodies while indexing, discard intermediate resolution failures, and do not
  activate unrelated project files merely because another file has annotations.
- First build passed. Initial public-boundary failures were two expectation
  mismatches (unrelated modules must not activate analysis; missing source
  directories retain the existing typed read error), plus collector fixture
  syntax corrections. These were recorded and resolved as a group.
- Expanded integration tests cover matching `.res`/`.resi` exception identities,
  rebind equivalence classes, earlier shadowed exceptions, malformed provider
  byte ranges, unvisited provider function bodies, signature opens/includes,
  nested signature export isolation, reverse alias chains and unsupported cycles.
- Added declaration-only annotation-placement validation without descending into
  function bodies. Unsupported metadata is not silently treated as an unannotated
  function.
- Compiled a real four-module/interface fixture project using installed ReScript
  12.3.1 at `/tmp/rescript-project-throws-compile.b4SwKR`. Project-mode unhandled
  imported calls exited 1 at the exact callee; named handlers and aliases exited
  0. The unannotated caller without a configured project exited 0 as before.
- Updated README, npm README, rule contracts, plan and THROWS.md with the new
  behavior and remaining dependency/runtime/type boundaries. Implementation-local
  declarations retain local contracts; interfaces govern imported references.
- Grouped final review exposed two declaration-indexing gaps: unresolved
  qualified exported aliases could become plain values, and exported initializer
  aggregates/higher-order arguments could hide known annotated functions. Both
  now produce provider-located analysis errors. The initializer fix reuses the
  existing lexical traversal, while skipping ordinary provider function bodies
  and initializer callee effects. Regression tests cover both boundaries.

## Verification

- `make check coverage`: passed, including 96 project throws integration cases,
  66 dependency collector cases, seven new CLI checks and existing regressions.
- Coverage: **95.40% (6538/6853 execution points)**; every implementation module
  remains above 90%. `Throws_project` is 100%, `Throws_dependencies` 93.39%,
  `No_unhandled_throws` 98.87%, `Throws_scope` 96.88%, and `Linter` 100%.
  Report: `_coverage/run.l3QNOT/html/index.html`.
- Parallel work logs: [integration tests](RULE_WORK_PROJECT_THROWS_TESTS.md)
  and [dependency collector](RULE_WORK_THROWS_DEPENDENCIES.md).
- Release `opam exec -- dune build -p rescript_linter --profile release @install`:
  passed. Compiler-backed catalog audit: **198/198**, no skips; pinned ReScript
  12.3.1, React bindings 0.15.0 and rescript-vitest 3.0.1, plus real Reanalyze
  output with 189 findings. Release binary SHA256:
  `96f8ca3ea0dab78ab26477e6d92fe5abbeaf4cfa54b90fcf34375a24a3baacb4`.
- `npm run prepare:licenses`: passed; source/license provenance now matches the
  settled native sources and release build.
- `npm test`: **43/43 passed**, with 100% measured launcher/packaging line,
  branch and function coverage.
- `npm run test:rebuild`: passed; the distributed application/compiler sources
  rebuilt and relinked with a deliberately modified library in isolation.
- `npm run pack:native` and `npm run test:package`: passed; freshly packed Linux
  x64 packages installed and ran without OCaml tools on PATH. Tarballs remain
  local under ignored `dist/`; nothing was published.
- Final `git diff --check`: passed. No pending test failures, running required
  commands, new dependencies, commits, pushes or release tags.

## Remaining Boundaries

- Dependency/runtime throws contracts, named module types and advanced semantic
  forms still require further work. This is declaration-contract checking, not
  compiler-equivalent effect inference or proof of annotation completeness.
- Imported opens produce conservative dependency sets; indexing is not cached
  across files and other unsaved editor buffers are not combined into a snapshot.
- The next item in the project plan is alias/open resolution for the older
  banned-API rules, separate from this completed project-throws task.
