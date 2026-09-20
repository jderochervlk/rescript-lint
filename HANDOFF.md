# ReScript Linter Handoff

Last updated: 2026-09-19

This document records the verified parser integration, `no-console`, and `no-object-magic` work. The first milestone was committed as `ff28310` and pushed to `origin/main`. The next milestone adds the verified unchecked-cast rule and shared traversal. Use `git status` and `git log` for current commit and worktree state; preserve any later uncommitted work.

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
- Git repository uses `main`, tracking `origin/main` at `git@github.com:jderochervlk/rescript-linter.git`. The initial planning commit is `2e6efb3`.
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

`Banned_api.rule` contains an ID and a pure path-to-optional-message function. `Banned_api.check` visits the AST once, tracks the existing lexical scope, applies each rule at unshadowed value references, and sorts the collected diagnostics. `lib/linter.ml` registers both rules. Rule modules no longer own their own traversal. The only mutable accumulator is local to the compiler's unit-returning iterator boundary.

## Tests and verification

There are unit tests for command/application behavior and parser/rule behavior, plus Cram CLI tests. Fixtures include clean implementation/interface files, console findings, mixed cast/console findings, and invalid syntax. `test/no_object_magic_test.ml` covers both actual runtime exports and unrelated names, lexical scope, exception handlers, exact ranges/messages, Unicode, and cross-rule ordering.

Verification completed after resuming:

- The development build succeeded.
- The release `@install` build succeeded.
- `make check` passed, including formatting, unit tests, and Cram tests.
- Coverage passed at 99.45% overall.
- Every library file was at 100% coverage.
- `bin/main.ml` was exactly 90% because Bisect places one point after process termination.
- `git diff --check` passed.
- `opam lint` completed with only the expected missing `homepage`, `bug-reports`, and `license` metadata warnings. Those fields are intentionally undecided.

The latest coverage report is `_coverage/run.LBvmPB/html/index.html`. CLI tests confirm both rules report errors with exit code `1`, in source order. Earlier manual checks also confirmed successful parsing of the vendored runtime's real `Stdlib_Console.res` and `.resi` files with exit code `0`. The upstream submodule has no local modifications.

## Resume here

The parser, `no-console`, and `no-object-magic` are implemented. The suggested next implementation slice is below. These checks passed on the current implementation; rerun them after further code changes, sequentially:

```sh
cd /home/josh/Dev/rescript-linter
make check
make coverage
opam exec -- dune build --profile release @install
git diff --check
git status --short
```

Expected coverage is approximately 99.45% overall and exactly 90% for `bin/main.ml`. Do not weaken the 90% per-file threshold.

Then inspect the final CLI manually using repository fixtures:

```sh
opam exec -- dune exec rescript-lint -- test/fixtures/example.res
opam exec -- dune exec rescript-lint -- test/fixtures/console.res
opam exec -- dune exec rescript-lint -- test/fixtures/object_magic.res
opam exec -- dune exec rescript-lint -- test/fixtures/invalid.res
```

Files inside `vendor/rescript` can be linted through `dune exec`. A previous failure was reported during overlapping Dune invocations; the same command passed when run sequentially after the build completed. Avoid concurrent Dune build/exec operations in this workspace. Alternatively, invoke `_build/default/bin/main.exe` directly after building.

The generated root `compile_commands.json` contains an absolute path into the local compiler switch. It is now ignored through `/compile_commands.json` in `.gitignore` and remains available locally.

The user requested committing and pushing the `no-object-magic` milestone after reviewing its verification results. Check `git status --short --branch` and `git log` for the current synchronization state before further Git operations.

## Suggested next implementation slice

The next rule is `no-unsafe`, using the shared `Banned_api` traversal already used by `no-console` and `no-object-magic`.

Avoid abstracting too early. A useful progression is:

1. Inspect the pinned runtime to establish exact unsafe API names and module exports.
2. Add an explicit, versioned inventory as a new `Banned_api.rule` and register it in `lib/linter.ml`.
3. Test references as values, calls, pipes, local module shadowing, comments/strings, and every `getUnsafe` argument shape.
4. Keep each rule's diagnostic ID/message distinct.

Module alias/open resolution is also a good nearby task, but it should be designed as actual scope-aware resolution rather than string matching. The current `no-console` limitations provide concrete tests for it.

React hooks can start as a bounded source-level control-flow check. The `@throws` rule should wait for a semantic integration spike because its hard guarantee requires callee identity, annotation lookup across files/interfaces/externals, and complete handler coverage. The research in `docs/RULES.md` includes ReScript's existing exception analyzer and the stricter policy requested here.

## Important files

- `README.md`: setup, CLI contract, current behavior
- `docs/PLAN.md`: milestones and immediate next work
- `docs/RULES.md`: full requested rule contracts and research
- `docs/DEPENDENCIES.md`: parser pin, build boundary, licenses, upgrades
- `dune-project`: versions and package dependencies
- `rescript_linter.opam.template`: Flow parser pin
- `vendor/dune`: nested-project exclusion and parser adapter inclusion
- `vendor/parser/`: Dune adapters for official compiler source
- `lib/parser.ml`: in-memory parser boundary
- `lib/source_range.ml`: UTF-16-to-UTF-8 position conversion
- `lib/no_console.ml`: first real lint rule
- `lib/no_object_magic.ml`: unchecked-cast rule and exact runtime inventory
- `lib/banned_api.ml`: shared qualified-reference traversal and module scope
- `lib/linter.ml`: source-read/parse/rule composition
- `lib/application.ml`: multi-file CLI behavior
- `test/linter_test.ml`: parser, range, shadowing, and API inventory tests
- `test/no_object_magic_test.ml`: unchecked-cast and cross-rule regressions
- `test/cli.t`: end-to-end CLI expectations
- `scripts/coverage.sh`: per-file and overall coverage gate

## Dependency and license caution

Do not describe the parser dependency as MIT-only. ReScript's syntax files carry MIT licensing, while linked compiler sources include LGPL and inherited OCaml notices/linking exceptions. The Flow parser fork is MIT. Upstream notices remain in the submodule. This project's own license has not been selected.

Do not add more production dependencies without asking the user first. The user already approved the official ReScript parser and its required transitive dependencies.
