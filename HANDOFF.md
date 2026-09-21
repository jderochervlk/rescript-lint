# ReScript Linter Handoff

Last updated: 2026-09-21

This document records the parser integration and initial rule subsets. The original five rules and PR CI were followed by npm packaging, MIT licensing, and the sixth rule (`blank-lines`) with `--fix`, pushed to `origin/main` as `d9aeeef`. See the updates at the end of this document and consult Git for current commit/push status; preserve any later changes.

## User intent

Build a new ReScript linter in OCaml, using Dune and the official ReScript parser. The requested rules and decisions are:

1. `no-console` first.
2. Ban unchecked casts, originally called `Object.magic` in planning. Runtime inspection established the actual API is `Obj.magic`; the rule ID remains `no-object-magic`.
3. Ban unsafe APIs, including every `getUnsafe` call. `getUnsafe(None)` and `getUnsafe(Some(value))` are equally violations; catching errors does not exempt the call.
4. Add a useful, deliberately incomplete React rules-of-hooks check.
5. Make unhandled calls to `@throws` functions hard lint errors. Legacy `@raises` must also be recognized. A call is acceptable only when the declared exceptions are actually handled by ReScript exception-pattern matching or `try`/`catch`; adding `@throws` to the caller is not sufficient.

The detailed rule contracts and researched exception-handling semantics are in `docs/RULES.md`.

## Repository and toolchain

- Repository: `/home/josh/Dev/rescript-linter`
- Git repository uses `main`, tracking `origin/main` at `git@github.com:jderochervlk/rescript-lint.git`. The GitHub repository was renamed to `rescript-lint`; the local folder and OCaml package names remain unchanged. The initial planning commit is `2e6efb3`.
- Local Opam switch: `_opam/`
- Opam: 2.6.0
- OCaml: 5.5.0
- Dune: 3.24.2
- OCamlformat: 0.29.0
- ReScript submodule: v12.3.1, commit `679406560d169f1124653ab50795d5077570f078`
- Flow parser pin: `9ea4062c0b7e037415c4413a7634c459ebd5c31b`
- Bisect PPX pin: PR 448 commit `7061d643ff492b0045796357ee6917ded21fb1f0`

The milestone includes the scaffold, implementation, tests, documentation, `.gitmodules`, and the pinned ReScript Git submodule. The local toolchain, build outputs, coverage reports, and generated compilation database are ignored.

## What is implemented

### CLI and application boundary

The executable is `rescript-lint`. It accepts explicit `.res` and `.resi` paths, supports `--help`, `--version`, and `--`, and uses these exit codes:

- `0`: clean input, help, or version
- `1`: lint findings
- `2`: usage, read, unsupported-file, or parse failure

The runner continues across files. Analysis failure takes precedence over lint findings. Lint findings are rendered to stdout; analysis failures are rendered to stderr.

`lib/application.ml` is independent of the parser and receives a lint function as a dependency, which makes the command behavior easy to unit test.

### Parser integration

The linter uses the official ReScript 12.3.1 parser in process. It does not invoke the compiler executable.

ReScript's `syntax` library is private to its own Dune project. The build adapter under `vendor/parser/` copies the upstream `compiler/ext`, `compiler/ml`, and `compiler/syntax/src` source files into Dune's build tree and recreates their library stanzas. The upstream checkout remains unchanged. `vendor/rescript` is marked `data_only`; `vendor/parser` is marked vendored.

`lib/parser.ml` calls:

- `Res_driver.parse_implementation_from_source`
- `Res_driver.parse_interface_from_source`

Both are called with `for_printer:true` to preserve source-level syntax useful for linting. Do not switch to the file-based parser APIs: those can print errors and terminate the process.

Parser diagnostics become `Lint_error.Parse_errors of Diagnostic.t * Diagnostic.t list`, deliberately representing a non-empty list. A recovered AST with any syntax diagnostics is rejected; lint rules do not run on invalid source.

### Source positions

The public diagnostic convention is:

- one-based line
- one-based UTF-8 byte column
- zero-based absolute UTF-8 byte offset
- exclusive end position

ReScript's parser positions are unusual: `pos_bol` is an absolute byte offset, while `pos_cnum - pos_bol` is a UTF-16 code-unit column. `lib/source_range.ml` translates this mixed representation back to byte offsets using the original source string. Tests cover two-byte UTF-8, astral Unicode, previous-line Unicode, EOF, and newline boundaries. Preserve this conversion; directly exposing `Lexing.position.pos_cnum` is incorrect.

### `no-console`

`lib/no_console.ml` defines a syntax-only rule over the shared traversal in `lib/banned_api.ml`. It recognizes the pinned runtime's console members under:

- `Console`
- `Stdlib.Console`
- `Stdlib_Console`
- `Js.Console`
- `Js_console`
- legacy `Js.log`, `Js.log2`, `Js.log3`, `Js.log4`, and `Js.logMany`

It reports references, not just calls. Therefore pipes, callbacks, and `let log = Console.log` are caught at the qualified reference. Comments and strings are naturally excluded by AST traversal. Attribute payloads are intentionally skipped.

It has basic lexical module-shadow tracking:

- ordinary module declarations shadow subsequent items, but not their own initializer
- recursive module names are visible in all recursive module bodies and afterward
- block-local modules shadow only their body
- functor parameters shadow only their body
- nested module declarations do not leak outward

Diagnostics are sorted by source offset.

This is not symbol resolution. Current known limitations:

- `module Log = Console; Log.log(1)` is missed
- `open Console; log(1)` is missed
- opens/includes, unpacked modules, and module-type functors are not modeled
- cross-file aliases are not modeled
- a project-defined top-level `Console` module can be falsely identified before a local binding proves shadowing
- custom externals and raw JavaScript are outside this rule

These limits are documented in `docs/RULES.md` and `README.md`. Do not claim semantic completeness.

### `no-object-magic` and shared traversal

`lib/no_object_magic.ml` bans `Obj.magic`, `Primitive_object.magic`, and `Primitive_object_extern.magic`. The pinned runtime defines the first and third as unchecked identity casts and re-exports the third through the second. `Object.magic`, `Stdlib.Obj.magic`, and `Js.Obj.magic` are not standard APIs in this release and are not matched. The original planning spelling was corrected in the rule documentation.

Calls, pipes, callbacks, and value aliases are reported at the reference, including casts inside try/catch or exception switches. Messages suggest a typed conversion or input validation. Local module shadows are respected. Module aliases, opens, custom identity externals, and project-wide symbol resolution remain outside this implementation.

`Banned_api.rule` contains an ID and a pure path-to-optional-message function. `Banned_api.check` visits the AST once, tracks the existing lexical scope, applies each rule at unshadowed value references, and sorts the collected diagnostics. `lib/linter.ml` registers the three banned-API rules, runs the separate hooks and throws traversals, and merges successful findings in source order. Throws analysis failures return typed errors rather than partial lint findings for that file. Mutable accumulators stay local to the compiler's unit-returning iterator boundary.

### `no-unsafe`

`lib/no_unsafe.ml` classifies explicitly inventoried qualified API paths from the pinned runtime. `docs/UNSAFE_APIS.md` lists the exact members and namespaces: modern standard-library modules, legacy `Js` modules and typed arrays, `Belt` arrays/options/set constructors, and selected older exports. It recognizes both public aliases and direct implementation-module paths. It does not use a name-substring policy for arbitrary functions.

Both `Option.getUnsafe(None)` and `Option.getUnsafe(Some(value))` fail. Known-present branches, try/catch, and exception switches do not exempt a banned reference. Pipes, callbacks, and captured references are covered. Existing lexical shadows are respected. Module aliases, opens, custom libraries, unqualified globals, and runtime internals outside the inventory remain unsupported. `Option.getOrThrow` is intentionally left to the future exception policy.

Public interfaces matter: `Stdlib_Array.res` defines unsafe implementation helpers that are hidden by `Stdlib_Array.resi`, while `Belt.Array` exposes several similarly named functions. The inventory follows exports, not every name found in implementation bodies. `test/no_unsafe_inventory_test.ml` independently parses 33 selected runtime source/interface files and checks unsafe-named value exports plus non-unsafe negative cases. The test reads ASTs; it does not derive expectations from the rule's own inventory.

### `react/rules-of-hooks`

`lib/rules_of_hooks.ml` implements a separate contextual AST traversal. Hook names follow `use[A-Z0-9]`, qualified or unqualified. Function bindings annotated `react.component`, `jsx.component`, or `react.componentWithProps` and conventionally named custom hooks are valid owners. Direct `React.memo`/`React.forwardRef` wrappers preserve context on annotated bindings; comparator and other callbacks do not.

Ordinary hooks fail in branches, switch guards/arms, short-circuit right operands, loops, callbacks, module initializers, ordinary functions, try/catch, async functions, and default arguments. Completed branches do not taint later calls. An entire switch with any exception pattern is conservatively treated as an exception-handling region. Exactly bare `use` and `React.use` allow conditions and loops, while retaining the other restrictions. React's official specification was checked on 2026-09-20; no binding package is installed or pinned.

Each actual function starts a fresh immutable context, including nested named custom hooks. The parser represents a multi-parameter function as nested `Pexp_fun` nodes: outer `arity = Some n`, remaining parameters `arity = None`. Consume exactly that parameter count before visiting the body, so returned functions are not mistaken for later parameters. Type constraints and locally abstract type wrappers are transparent. Source-level pipes and short-circuit operations are `Pexp_apply` with `->`, `&&`, or `||` identifiers. Piped bare references are calls; nested piped applications are not reported twice. Attribute payloads stay opaque, and modules reset owner context.

This is intentionally bounded syntax analysis. It does not resolve aliases/shadows, infer unknown wrappers, prove every execution path, analyze indirect calls, or check dependency arrays. Partial applications and placeholder-generated functions are conservative syntactic checks, not semantic execution modeling. Non-React functions following the hook naming convention can be flagged. Plain hook references are not calls. See `docs/RULES.md` for the full scope and limitations; do not claim parity with the React ESLint rule.

### `no-unhandled-throws`

The source-preservation spike and first local enforcement pass are implemented. Read `docs/THROWS.md` before extending it: this is not project-wide checked exceptions. The pass activates only in files containing `@throws` or `@raises`. It does not load adjacent `.res`/`.resi` files, compiler artifacts, implicit standard-library contracts, or project metadata. A file with no local annotation is outside this pass, not proven exception-safe.

`Throws_annotation` decodes bare, constructor, and nonempty array/tuple payloads with typed errors for unsupported forms. `Throws_scope` maintains immutable value contracts, module exports, and exception identities. It supports simple value aliases, sequential/recursive value bindings, local modules/aliases, opens/includes, parameter/pattern shadowing, and exception aliases. Module exports do not include inherited outer declarations. Contracts capture constructor identities at declaration time, so later shadows cannot accidentally discharge an old exception.

`Throws_handler` computes conservative unguarded pattern coverage. A bare annotation requires a whole-exception wildcard/bound-variable catch-all; named exceptions require matching constructors with irrefutable payloads. Tuple payloads, aliases/type constraints, and or-patterns are supported; partial literal/record payload coverage is not proved. Nested enclosing handlers may jointly cover obligations. Try catches protect only the body; switch exception arms protect only the scrutinee. Handler guards/bodies and normal result arms retain only outer handlers. Every actual function starts with empty handler coverage, preserving the parser's multi-parameter arity representation.

`No_unhandled_throws` diagnoses direct/piped calls and keeps annotated simple aliases traceable. Caller annotations and `@doesNotThrow` do not count as handling. Unsupported known contract escapes, malformed annotation positions/payloads, unresolved qualified values/modules, async/await/direct promise-result cases, and unsupported module/interface forms produce `Lint_error.Analysis_errors`, a nonempty collection of `throws-analysis` diagnostics. CLI exit `2` means analysis failed; exit `1` means a known call lacks handling. Other input files still run. Unknown unqualified calls and effects of unannotated functions are not inferred. Hidden async results/type aliases remain unresolved; do not claim promise-rejection correctness.

The pinned runtime's `Stdlib_JSON.res` confirmed bare annotations, and upstream analysis fixtures confirmed named/list payloads. The pinned `analysis/reanalyze/src/Exception.ml` uses typed trees, `processCmt`, and merged per-file value tables. That was inspected as a future integration direction, not copied or newly linked. No new production dependency was added. `.cmt`/`.cmti` compatibility is not yet established.

## Tests and verification

There are unit tests for command/application behavior and parser/rule behavior, plus Cram CLI tests. Fixtures cover all five subsets, clean files, invalid syntax, and explicit incomplete throws analysis. Hooks tests cover the placement matrix and parser-specific function boundaries. Throws tests cover handling forms, guards/payload coverage, scope/identity, aliases, interfaces/externals, unsupported constructs, exact messages/ranges, and Unicode. The model tests exercise unresolved compiler AST paths and module-pattern shadows directly. Existing unsafe inventory tests remain intact.

Verification completed after resuming:

- The development build succeeded.
- The release `@install` build succeeded.
- `make check` passed, including formatting, unit tests, and Cram tests.
- Coverage passed at 99.88% overall (852/853 execution points).
- Every library file was at 100% coverage.
- `bin/main.ml` was exactly 90% because Bisect places one point after process termination.
- `git diff --check` passed.
- Earlier `opam lint` verification reported only the expected missing `homepage`, `bug-reports`, and `license` metadata warnings. Hooks and throws did not change dependencies or package metadata.

The latest coverage report is `_coverage/run.kAdk9L/html/index.html`. CLI tests confirm findings exit `1`; `throws_unsupported.res` exits `2` and subsequent files still run. `hooks_clean.res` and `throws_clean.res` pass. Earlier manual checks confirmed parsing of the vendored runtime's real `Stdlib_Console.res` and `.resi` with exit `0`. The upstream submodule remains unchanged.

## Resume here

The parser and five initial rule subsets are implemented. The suggested next implementation slice is below. These checks passed on the current implementation; rerun them after further code changes, sequentially:

```sh
cd /home/josh/Dev/rescript-linter
make check
make coverage
opam exec -- dune build --profile release @install
git diff --check
git status --short
```

Expected coverage is approximately 99.88% overall and exactly 90% for `bin/main.ml`. Every library module, including hooks and throws, has 100% execution-point coverage. Do not weaken the 90% per-file threshold.

Then inspect the final CLI manually using repository fixtures:

```sh
opam exec -- dune exec rescript-lint -- test/fixtures/example.res
opam exec -- dune exec rescript-lint -- test/fixtures/console.res
opam exec -- dune exec rescript-lint -- test/fixtures/object_magic.res
opam exec -- dune exec rescript-lint -- test/fixtures/unsafe.res
opam exec -- dune exec rescript-lint -- test/fixtures/hooks_clean.res
opam exec -- dune exec rescript-lint -- test/fixtures/hooks.res
opam exec -- dune exec rescript-lint -- test/fixtures/throws_clean.res
opam exec -- dune exec rescript-lint -- test/fixtures/throws.res
opam exec -- dune exec rescript-lint -- test/fixtures/throws_unsupported.res
opam exec -- dune exec rescript-lint -- test/fixtures/invalid.res
```

Files inside `vendor/rescript` can be linted through `dune exec`. A previous failure was reported during overlapping Dune invocations; the same command passed when run sequentially after the build completed. Avoid concurrent Dune build/exec operations in this workspace. Alternatively, invoke `_build/default/bin/main.exe` directly after building.

The generated root `compile_commands.json` contains an absolute path into the local compiler switch. It is now ignored through `/compile_commands.json` in `.gitignore` and remains available locally.

The user requested committing and pushing hooks and source-local throws together after their verification. Check `git status --short --branch` and `git log` for the resulting milestone and current tracking state before further Git operations.

## Suggested next implementation slice

The next step is project-aware throws metadata. Source annotation preservation and same-file scope resolution are proven. Now establish project discovery, `.res`/`.resi` precedence, external/dependency contracts, canonical cross-file identities, and stale/missing metadata diagnostics. Choose a project declaration index or prove compatible compiler artifacts before expanding the enforcement guarantee. `docs/THROWS.md` lists the deliberate current limits.

The CLI now supports polling-based watch mode for explicit file paths. Deterministic directory discovery remains separate planned work and should feed both one-shot and watch execution. The editor path should expose the shared lint engine through an LSP server that consumes document notifications directly; CLI watch mode is not the LSP transport. Build the Zed extension first, then reuse the server from a VS Code client.

Module alias/open resolution is also a good nearby task, but it should be designed as actual scope-aware resolution rather than string matching. The current `no-console` limitations provide concrete tests for it.

The `@throws` rule requires actual handling, not just propagation annotations. An exception-pattern switch protects its scrutinee, and try/catch protects its body; handler bodies and later function execution do not inherit that protection. Guards and partial payload matches are not exhaustive. The research in `docs/RULES.md` includes ReScript's existing exception analyzer and the stricter policy requested here. Legacy `@raises` is deprecated in favor of `@throws`, but both must be recognized.

## Important files

- `README.md`: setup, CLI contract, current behavior
- `docs/PLAN.md`: milestones and immediate next work
- `docs/RULES.md`: full requested rule contracts and research
- `docs/UNSAFE_APIS.md`: exact versioned unsafe-API inventory and exclusions
- `docs/THROWS.md`: local enforcement boundary, verified research, and next metadata work
- `docs/DEPENDENCIES.md`: parser pin, build boundary, licenses, upgrades
- `dune-project`: versions and package dependencies
- `rescript_linter.opam.template`: Flow parser pin
- `vendor/dune`: nested-project exclusion and parser adapter inclusion
- `vendor/parser/`: Dune adapters for official compiler source
- `lib/parser.ml`: in-memory parser boundary
- `lib/source_range.ml`: UTF-16-to-UTF-8 position conversion
- `lib/no_console.ml`: first real lint rule
- `lib/no_object_magic.ml`: unchecked-cast rule and exact runtime inventory
- `lib/no_unsafe.ml`: unsafe API inventory and rule
- `lib/rules_of_hooks.ml`: function and placement context, hook recognition, traversal
- `lib/no_unhandled_throws.ml`: source-local contract traversal and analysis failures
- `lib/throws_annotation.ml`, `lib/throws_scope.ml`, `lib/throws_handler.ml`: decoding, identities, and coverage
- `lib/banned_api.ml`: shared qualified-reference traversal and module scope
- `lib/linter.ml`: source-read/parse/rule composition
- `lib/application.ml`: multi-file CLI behavior
- `test/linter_test.ml`: parser, range, shadowing, and API inventory tests
- `test/no_object_magic_test.ml`: unchecked-cast and cross-rule regressions
- `test/no_unsafe_test.ml`: unsafe arguments, handlers, scopes, ranges, and rule interaction
- `test/no_unsafe_inventory_test.ml`: independent check against pinned runtime exports
- `test/rules_of_hooks_test.ml`: hooks placement matrix, parser boundaries, ranges/messages
- `test/no_unhandled_throws_test.ml`, `test/throws_model_test.ml`: enforcement and unsupported-analysis regressions
- `test/cli.t`: end-to-end CLI expectations
- `scripts/coverage.sh`: per-file and overall coverage gate

## Dependency and license caution

Do not describe the parser dependency as MIT-only. ReScript's syntax files carry MIT licensing, while linked compiler sources include LGPL and inherited OCaml notices/linking exceptions. Flow's parser is MIT but its inherited OCaml collections include LGPL code. The user selected MIT for this project's original code; the root `LICENSE` names Josh Vlk, 2026. Dune/Opam and launcher metadata declare MIT. The source-accompanying distribution implementation is described in the final update below.

Do not add more production dependencies without asking the user first. The user already approved the official ReScript parser and its required transitive dependencies.

## npm packaging update

New packaging work uses `@jvlk/rescript-lint` and four exact-version optional
native packages. See `docs/NPM.md` for the full design, commands, platform matrix,
and release checklist. `npm/` contains the dependency-free Node launcher and
source manifests; `scripts/npm/` stages/packs them; `test/npm/` covers the wrapper,
packaging, and offline installation. Node 24+ is required for these checks.

Run `opam exec -- dune build --profile release @install`, then `npm test`,
`npm run pack:native`, and `npm run test:package`. The new npm workflow runs this
on Linux x64/ARM64 and macOS x64/ARM64. All four targets passed on `98e7e4d`.
Windows was deferred at the user's request after fixture tests failed there.
The existing OCaml checks workflow remains unchanged.

Publication is intentionally disabled: all manifests are private. Both package types include our MIT `LICENSE`;
native manifests point to `DISTRIBUTION.md` rather than claim the binary is MIT-only.
No npm publishing credentials, release job, or binary uploads were added.
The initial distribution checklist was subsequently replaced by the source-bundle
implementation described at the end of this document.
This packaging work was committed and pushed in `d9aeeef`.

Local verification: release build and `make check` passed; 26 npm tests passed
with 100% line/branch/function coverage for all six launcher/packaging source
files. The packed Linux x64 install passed CLI and package-content checks.
Both workflow files passed Actionlint. Hosted target builds remain unverified.

## Spacing and autofix update

`blank-lines` is enabled by default. See `docs/BLANK_LINES.md` for the detailed
formatter-compatible boundary contract. It handles declarations/local statement
rows and JSX siblings, not arbitrary nested expressions or padding near braces.
All pipe statement/binding chains qualify, including single-line chains.

`Diagnostic.t` now has a `fixes` field containing validated byte-range edits.
`Parser.parse_document` retains comments, and `Parser.format` uses the already
linked official formatter in memory. `Layout_node` classifies AST rows;
`Blank_lines` identifies gaps; `Text_edit` validates/applies edits; `Fixer`
re-lints, checks formatter stability, and uses `Source.write` for replacement.
`Application.run` now takes both `lint` and `fix` callbacks. `--fix` reports
remaining diagnostics and preserves exit-code precedence across files.

No third-party production dependency was added. `unix` is the OCaml standard
library used for file metadata and replacement. Writes reject stale content,
symlinks, hardlinks, read-only files, and nonregular files. Existing semantic
rule tests retain their assertions; their input spacing was updated where
necessary to comply with the new default rule.

The GitHub repo was renamed to `jderochervlk/rescript-lint`. The SSH remote,
npm links, and Dune-generated Opam homepage/issues/dev-repo now use that name.
The local folder remains `/home/josh/Dev/rescript-linter`.

Latest verification: `make check`, release `@install`, and `opam lint` passed.
`make coverage` passed at 98.84% overall (1107/1120), with every own source file
at or above 90%; report: `_coverage/run.Zt9d8h/html/index.html`. All 26 npm tests
passed at 100% launcher/packaging coverage, and the packed Linux install passed
the new `--fix` smoke test. Actionlint and `git diff --check` passed. The renamed
remote resolves correctly. This milestone was subsequently pushed as `d9aeeef`.

## Release preparation update

`docs/RELEASING.md` records the registry preflight, remaining release gates,
approved beta version, publishing order, and recovery procedure. npm is
authenticated as `jderochervlk`, an owner of the `@jvlk` organization. All six
intended package names returned HTTP 404 on 2026-09-20. Nothing was published.

Packages now use `npm/README.md` instead of the development README. Staging
and installed-package tests check that exact documentation. The initial link
inventory in `docs/DISTRIBUTION.md` includes the transitive runtime libraries;
the completed license/source bundle implementation is described below.

Hosted workflows were started by the push. Consult GitHub Actions for current
results rather than assuming that local Linux success verifies all targets.
Publication guards remain in place; no release workflow or credentials were added.

The maintainer approved version `0.1.0-beta.1` and npm dist-tag `beta`. Version
metadata, CLI output, and tests are synchronized; both generated package types
default to `beta` through `publishConfig`. The Git release tag is deferred until
the release gates pass. No npm publication has occurred.

First-release priority is Linux for user testing, with macOS included because
both architectures pass. Windows is removed from the shared target manifest,
which also removes its CI job and optional package dependency. Existing Windows
test scaffolding remains for later work; `docs/NPM.md` records the re-entry checks.
The original license blocker was an unfinished third-party distribution bundle,
not a build failure or a demonstrated incompatibility with our MIT license.

## License/source bundle implementation

The user requested resolving the licensing issue before further publication work.
Native packages now carry `third-party/`: complete pinned source archives for
ReScript, Flow, OCaml, Base, Sexplib0, OCaml intrinsics kernel, WTF-8, and PPX
deriving; extracted upstream license/notice files; the application sources and
build adapters; checksums; and rebuild/relink instructions. The launcher remains
MIT-only; the native package points to `DISTRIBUTION.md` for the mixed terms.

The approach supplies corresponding library and application source with the
binary under LGPL v3 4(d)(0) and LGPL v2.1 6(a). It does not depend on proving a
blanket linking exception for every inherited compiler file. Source archives
retain upstream notices and licenses; our application code stays MIT. The bundle
is about 20 MB before npm compression. No new production dependency was added.

`scripts/npm/dependencies.json` records reviewed versions, URLs, revisions, and
hashes. `compliance-prepare.mjs` checks the installed versions, Flow revision, and
clean pinned ReScript checkout, rejects local replacement pins, verifies downloads,
extracts notices, and captures source/binary hashes. `compliance.cjs` gates package
staging on complete, unchanged bundle contents and matching source/binary hashes.
Archives/cache live under ignored `dist/compliance/`, not Git.

Required order: release `@install`, `npm run prepare:licenses`, `npm test`,
`npm run test:rebuild`, `npm run pack:native`, `npm run test:package`. Re-prepare
after changing native sources or rebuilding the binary. Preparation needs network
access only for uncached archives; consumers never download at install time.
The npm CI matrix now includes preparation and a source rebuild/relink check.

The rebuild test uses an isolated directory with the bundled application and
ReScript sources, changes a library initializer, rebuilds, and observes that
initializer at runtime. It passed locally. It uses the installed Opam dependencies,
so this is not a full offline bootstrap or bit-identical reproducibility test.
Hosted verification of the new bundle steps remains pending. No publication,
release tag, commit, or push was performed for this work.

Final license verification used an isolated source snapshot at
`/tmp/rescript-license-check.w2c20C` because concurrent watch-mode edits/builds
correctly invalidated the shared checkout's prepared bundle. The isolated release
build passed; all 43 npm/compliance tests passed at 100% line/branch/function
coverage for all nine packaging/launcher modules; the packaged Linux install
and modified-library rebuild tests passed. Actionlint and `git diff --check`
passed. The native tarball is about 23 MB including the binary and source bundle.

The snapshot's broader release `dune runtest` failed in the concurrent watch-mode
Cram test: `watched-fix.res` was read-only, so `--fix` refused it. License work did
not change those watch files or weaken that check. Consult the other work's latest
state before treating this as an outstanding failure. Regenerate the shared
checkout's bundle after its native sources/build settle; do not bypass the stale
source/binary safeguards just to reuse an earlier snapshot.

## Combined watch and distribution verification

After watch-mode work finished, the user requested committing and pushing all
changes together. The read-only watch fixture was fixed by making its temporary
copy writable. Verification against the settled shared checkout passed:

- Release-profile tests and `make check`, including watch-mode CLI tests.
- `make coverage`: 98.81% overall, 100% for `lib/watch.ml`, every file above 90%.
- Release build followed by fresh `npm run prepare:licenses`.
- All 43 npm tests, with 100% line/branch/function coverage.
- Bundled-source rebuild with a modified library.
- Native/launcher tarball packing and Linux x64 installation without OCaml on PATH.
- Actionlint for both workflows and `git diff --check`.

This supersedes the earlier snapshot's watch-fixture failure. Hosted checks on
the combined commit remain the next release gate; npm publication and the release
tag remain deferred.

## Syntax rule expansion, 2026-09-20

Added twelve syntax rules through three parallel agents, retaining the previous
ten-rule baseline and pre-existing uncommitted work. The registry now contains
22 rules: twelve defaults and ten opt-in policies. `--list-rules`,
`--enable-rule ID`, and `--disable-rule ID` work across lint, fix, watch, and LSP.
New rules emit diagnostics only; spacing remains the automatic fix provider.

The grouped follow-up resolved parser representation mismatches and narrowed
control-flow checks to avoid false positives across effects, pattern scopes,
standalone attributes, and incompatible literal semantics. Contracts and
limitations are in [docs/SYNTAX_RULES.md](docs/SYNTAX_RULES.md). The complete work
log, agent logs, issue history, and remaining infrastructure work are linked
from [docs/RULE_WORK_LOG.md](docs/RULE_WORK_LOG.md).

Full checks, CLI/LSP/watch regressions, coverage, and release @install passed.
Coverage is 98.30% (2261/2300 execution points), every file above 90%; report:
`_coverage/run.6eNcBY/html/index.html`. No dependencies were added, and no commit,
push, or publication was performed. Regenerate distribution/compliance bundles
from the final native sources before packaging.

## Complete catalog expansion, 2026-09-21

The user requested continuing beyond the first syntax batch until the remaining
catalog was implemented. Three agents and the main agent added the remaining
83 rules, for **105 registered rules**: twelve existing defaults and 93 opt-in
rules. All 99 research candidates have bounded implementations; the six earlier
rules remain. Delegate/Reject catalog entries are intentionally not implemented.

The new packs cover twenty semantic/API checks, 34 JSX accessibility checks,
twelve React checks, twelve test-framework checks, and five project policies.
Supporting infrastructure includes strict JSON configuration, explicit versioned
adapters, deterministic project discovery, interface-first public metadata,
source-inferred types/identities, opaque-export quarantine, fresh Reanalyze
report consumption, and audited suppression comments. No production dependency
was added. Older source-local throws and banned-API resolution limits remain;
this is not compiler-equivalent whole-program analysis.

Start with [docs/EXTENDED_RULES.md](docs/EXTENDED_RULES.md) for activation and
contracts. The full chronological record, grouped failures/fixes and final gate
results are in [docs/RULE_OVERNIGHT_LOG.md](docs/RULE_OVERNIGHT_LOG.md), with
links to each agent's work. The compiler-backed catalog runner regenerates and
builds all 198 invalid/valid examples and checks the real unused-export analyzer.

Production code passed `make check`, the release build and all 198 catalog
expectations with zero skips. Final coverage is 95.42%, every module above 90%;
all 43 npm tests passed at 100% packaging coverage after regenerating the
compliance bundle. Full results are recorded in the overnight log.
The previous first-wave 98.30% figure above
is historical, not the expanded implementation's coverage. No commit, push,
publication or new release tag was made during this work.

## Project-local throws contracts, 2026-09-21

The next plan item now connects `no-unhandled-throws` to the existing configured
project loader. Callers can resolve public `@throws`/`@raises` declarations across
files, with `.resi` precedence, nested modules, aliases, opens/includes and
implementation/interface exception identity equivalence. Source-only activation
is unchanged. Unsupported required metadata fails at the provider source range,
and declaration indexing does not analyze ordinary provider function bodies.

The main agent handled integration; two agents built the lexical dependency
collector and public-boundary regressions. Review found unresolved exported
aliases and annotated-function escapes in exported initializers; both now fail
explicitly and have passing tests. Logs and remaining boundaries are in
[docs/RULE_WORK_PROJECT_THROWS.md](docs/RULE_WORK_PROJECT_THROWS.md) and
[docs/THROWS.md](docs/THROWS.md).

`make check coverage` passed, including 96 project integration cases, 66 collector
cases and seven new CLI checks. Coverage is **95.40% (6538/6853)**, every module
above 90%, and `Throws_project` is 100%. Release `@install` and the compiler-backed
198-example catalog audit passed with zero skips. A real ReScript 12.3.1 fixture
also verified unhandled imported calls, named handlers and aliases. The source
and license bundle was regenerated for the new release binary.

All 43 npm tests passed at 100% measured packaging coverage. Bundled-source
rebuild/relink, native package packing and Linux x64 installation without OCaml
tools on PATH also passed. `git diff --check` is clean. The full gate results
and release binary hash are in the project throws log.

The rule count remains 105, with twelve defaults and 93 opt-in rules. No new
dependencies, commits, pushes or publication. Next planned work is older banned-API
alias/open resolution. Dependency/runtime exception contracts and compiler-backed
whole-program effects remain outside this implementation.
