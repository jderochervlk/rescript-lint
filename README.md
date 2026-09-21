# ReScript Linter

An extensible linter for [ReScript](https://rescript-lang.org/).

An early, working OCaml CLI with the official ReScript 12.3.1 parser and six initial rule subsets: `no-console`, `no-object-magic`, `no-unsafe`, bounded `react/rules-of-hooks`, source-local `no-unhandled-throws`, and autofixable `blank-lines`. It parses `.res` and `.resi` files directly, without running a compiler subprocess or requiring a project build.

## Current direction

Use OCaml with the official ReScript parser/AST. The pinned compiler checkout and build adapter are documented in [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md), including upstream licenses and upgrade steps.

Keep diagnostics and command behavior independent of compiler types; avoid designing a replacement AST before the rules need it.

## Project plan

See [docs/PLAN.md](docs/PLAN.md) for milestones, boundaries, and open questions. The editor work has a detailed [language server plan](docs/LSP.md). The language choice is recorded in [docs/decisions/001-implementation-language.md](docs/decisions/001-implementation-language.md).

## Development

Requires Opam 2.2 or newer, OCaml 5.5.0, Dune 3.24.2, and OCamlformat 0.29.0. On the development machine, Opam is installed at `/home/josh/.local/bin/opam` and the compiler switch is local to this repository in `_opam/`.

For a fresh checkout, first install and initialize [Opam](https://opam.ocaml.org/doc/Install.html), then run:

```sh
git submodule update --init
opam switch create . 5.5.0 --no-install
opam install . --deps-only --with-dev-setup --yes
make check
opam exec -- dune exec rescript-lint -- --help
```

`opam exec` selects the local switch without changing your shell configuration. Add your Opam binary directory to `PATH` if needed.

```sh
make build       # Compile library and CLI; enabled warnings are fatal
make test        # Unit tests and CLI fixtures
make format      # Apply OCamlformat and Dune formatting
make check       # Build, formatting check, and tests
```

Edit `dune-project` for package metadata. `make check` detects changes to the generated Opam file; after that check, run `opam exec -- dune promote rescript_linter.opam` to update it. The project's license is MIT; repository links point to `jderochervlk/rescript-lint`.

## License

Our original code is licensed under the [MIT License](LICENSE), Copyright (c) 2026 Josh Vlk. Third-party sources and linked dependencies retain their own licenses, including LGPL provisions and linking exceptions. The MIT license does not apply to the entire bundled dependency graph; see [the dependency notes](docs/DEPENDENCIES.md) and [distribution review](docs/DISTRIBUTION.md).

## Coverage

The published Bisect package and its main branch do not build with the PPX version required by OCaml 5.5. Development coverage uses the pinned compatibility commit from [Bisect PR 448](https://github.com/aantron/bisect_ppx/pull/448). This is an unmerged tooling workaround, not a runtime dependency.

```sh
make coverage-tools
make coverage
```

Each run writes fresh data and an HTML report under `_coverage/`. The check requires all `lib/` and `bin/` implementation files in the report and at least 90% execution-point coverage per file and overall; aim for 100%. Bisect measures instrumented execution points, not separate statement/branch/function/line percentages. Tests themselves are not instrumented.

## npm distribution

The planned npm package is **`@jvlk/rescript-lint`**, with the **`rescript-lint`** command and prebuilt native packages for Linux glibc x64/ARM64 and macOS Intel/Apple Silicon. Users will not need OCaml or Dune. All four targets passed hosted build and package-install checks on the beta preparation commit; the exact release commit must pass again. Windows is deferred to a later release.

Packaging includes third-party licenses and rebuildable source bundles; publication remains disabled pending release approval and platform verification. With Node 24+ and a release binary built, run `npm run prepare:licenses`, `npm test`, `npm run test:rebuild`, `npm run pack:native`, and `npm run test:package`. The npm workflow checks each target without publishing. See [docs/NPM.md](docs/NPM.md) for architecture, commands, compatibility boundaries, and the release checklist.

## Pull request CI

[GitHub Actions](.github/workflows/ci.yml) runs on pull requests, pushes to `main`, and manual dispatch. The `Checks (OCaml 5.5.0)` job uses Ubuntu 24.04, checks out the pinned ReScript submodule, and installs the repository's exact compiler/build/formatter versions and pinned coverage tooling.

The job runs `make check`, checks generated Opam metadata for drift, builds the release package, and runs `make coverage` with the existing 90% per-file and overall gate. Coverage summaries and HTML reports are retained as the `coverage-report` artifact for 14 days, including when the coverage gate fails after producing a report.

Action revisions are pinned to commit hashes. The workflow uses read-only repository permissions, does not persist checkout credentials, and cancels superseded runs. It uses `pull_request`, not `pull_request_target`, and requires no repository secrets. The OCaml setup action caches the Opam environment; build/test/coverage checks still run on every invocation.

After the first GitHub run, select `Checks (OCaml 5.5.0)` as a required status check in the `main` branch ruleset to prevent merging failing PRs. Adding this workflow does not itself enable branch protection.

## CLI contract

`rescript-lint [--fix] [--watch] [--] FILE.res [FILE.resi ...]` accepts explicit file paths in argument order. Help and version are available as standalone options. Directory discovery, JSON output, configuration, and project-wide exception metadata are planned work.

`rescript-lint lsp --stdio` starts the language server for editor clients. It
publishes diagnostics for unsaved `.res` and `.resi` buffers using full-document
synchronization and negotiated UTF-8 or UTF-16 positions. Protocol traffic is
written to stdout and logs to stderr. Zed integration is the next delivery step;
see the [language server plan](docs/LSP.md).

`--watch` (or `-w`) runs the selected lint or fix operation immediately, then reruns the full input set whenever a watched path changes. Findings and read, parse, or analysis failures do not stop the watcher; press Ctrl+C to stop it. Watch mode currently accepts explicit `.res` and `.resi` paths, not directories, and uses filesystem polling so atomic-save replacements and delete/recreate cycles are detected without an additional runtime dependency.

```sh
opam exec -- dune exec rescript-lint -- test/fixtures/console.res
```

The first diagnostic is `test/fixtures/console.res:1:1: error [no-console] Do not use Console.log.`; this fixture exits with code `1`.

`no-console` recognizes qualified standard console references, including pipes, callbacks, and value aliases such as `let log = Console.log`. It skips comments, strings, annotation payloads, and basic local module shadows. This is syntax-only analysis: module aliases, opens/includes, project-defined modules, and custom JavaScript bindings are not resolved. See [the rule's scope](docs/RULES.md#no-console) before using it as an enforcement gate.

`no-object-magic` bans `Obj.magic`, `Primitive_object.magic`, and `Primitive_object_extern.magic`, including references captured as values. In the pinned runtime, the unchecked cast is called `Obj.magic`; `Object.magic` is not a standard API.

`no-unsafe` bans an [explicit inventory](docs/UNSAFE_APIS.md) of unsafe APIs from the pinned standard library, `Js`, and `Belt`. Both `Option.getUnsafe(None)` and `Option.getUnsafe(Some(value))` fail, even inside try/catch or an exception switch. Qualified references captured as values also fail. Unrelated custom functions are not banned just because their names contain `Unsafe`.

The three banned-API rules use one traversal with the same shadowing checks and resolution limits. Try `opam exec -- dune exec rescript-lint -- test/fixtures/unsafe.res` to see them together.

`react/rules-of-hooks` checks calls named `use` followed by an uppercase ASCII letter or digit, qualified or unqualified. Hooks belong in annotated component bodies or named custom hooks, not ordinary functions, callbacks, module initializers, branches, loops, or exception handlers. It also rejects hooks in async functions and default arguments. Bare `use` and `React.use` allow branches and loops but still require a valid function context and cannot appear in exception-handling regions.

The hooks rule has its own contextual traversal. It supports multi-parameter functions and annotated components wrapped in `React.memo`/`React.forwardRef`. It does not resolve hook aliases or symbol identity, analyze every execution path, or check dependency arrays. Recognition is based on source spelling, not installed React bindings. See [the implemented scope](docs/RULES.md#reactrules-of-hooks) for exceptions and limitations. Try `opam exec -- dune exec rescript-lint -- test/fixtures/hooks.res` for failures or `test/fixtures/hooks_clean.res` for a passing example.

`no-unhandled-throws` requires handling for locally declared `@throws` and legacy `@raises` functions, including simple value/module aliases and local externals. It accepts applicable unguarded catches or switch exception patterns. Caller annotations and `@doesNotThrow` never discharge a call. Bare `@throws` requires a catch-all; guarded and payload-specific patterns are insufficient to cover an entire declared exception.

**This is not yet project-wide exception enforcement.** The throws pass activates only in files containing `@throws`/`@raises`; other files and imported runtime contracts are outside its scope. It does not combine `.res` and `.resi` files, even when both appear on the command line. In an annotated file, unresolved qualified values/modules, malformed annotations, known async cases, and unsupported contract escapes produce `throws-analysis` errors (exit `2`), not a clean result. Unknown unqualified calls and effects of unannotated functions are not inferred. See [the exact boundary and research](docs/THROWS.md) before relying on this rule.

Try `opam exec -- dune exec rescript-lint -- test/fixtures/throws.res` for unhandled calls, `test/fixtures/throws_clean.res` for both handling forms, or `test/fixtures/throws_unsupported.res` for an explicit analysis failure. Findings from all six subsets appear in source order.

`blank-lines` requires blank separators after externals and pipe statements/bindings, before annotated value bindings, and around switch statements/bindings. It supports nested blocks, signatures, and JSX sibling expressions. It does not pad block/file boundaries or arbitrary inline expressions. `rescript-lint --fix src/Example.res` applies minimal spacing edits, checks them against the pinned formatter, and reports remaining errors. Files with parse/analysis failures are left unchanged. See [the autofix contract](docs/BLANK_LINES.md) for safety checks and formatter-compatibility limits.

Exit codes: `0` clean/help/version, `1` remaining lint findings, `2` usage, input, analysis, fix, or write failures. The runner continues after file errors, with failures taking precedence over findings. Syntax errors go to stderr; lint findings go to stdout. No rules run on a recovered invalid parse tree. Diagnostics use one-based lines and UTF-8 byte columns, with zero-based byte offsets and exclusive range ends internally.
