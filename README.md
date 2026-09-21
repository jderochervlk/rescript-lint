# ReScript Linter

An extensible linter for [ReScript](https://rescript-lang.org/).

An OCaml CLI using the official ReScript 12.3.1 parser, with 105 registered rules: twelve enabled by default and 93 opt-in rules. It includes syntax policies, bounded semantic analysis, React/DOM accessibility, test-framework checks, and project policies. Syntax rules parse `.res` and `.resi` directly without a build; unused-export analysis requires fresh compiler artifacts and a Reanalyze report. See [extended rule contracts](docs/EXTENDED_RULES.md) for adapter requirements and precision limits.

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

`rescript-lint [--fix] [--watch] [--config FILE] [--project DIR] [--] FILE.res [FILE.resi ...]` accepts explicit file paths in argument order. With a project root and no explicit files, it discovers sources from `rescript.json` deterministically. Help and version are standalone options. JSON diagnostics remain planned work.

Use `--list-rules` to inspect default activation, and repeat `--enable-rule ID`
or `--disable-rule ID` to select exact rules. The last setting wins. Selection
applies to lint, fix, watch, and LSP modes. Optional rules and their initial
limits are documented in [the syntax rule reference](docs/SYNTAX_RULES.md).
The [extended reference](docs/EXTENDED_RULES.md) covers the other 83 rules,
JSON configuration, adapter activation, project metadata, and audited suppressions.

`rescript-lint lsp --stdio` starts the language server for editor clients. It
publishes diagnostics for unsaved `.res` and `.resi` buffers using full-document
synchronization and negotiated UTF-8 or UTF-16 positions. Protocol traffic is
written to stdout and logs to stderr. A development adapter for the existing
ReScript Zed extension is implemented; local editor validation and package
distribution are next. See the [language server plan](docs/LSP.md).

`--watch` (or `-w`) runs the selected lint or fix operation immediately, then reruns the full input set whenever a watched path changes. Findings and read, parse, or analysis failures do not stop the watcher; press Ctrl+C to stop it. Project discovery selects the initial watched file set; restart watch after adding new source files. Polling detects atomic-save replacements and delete/recreate cycles without an additional runtime dependency.

```sh
opam exec -- dune exec rescript-lint -- test/fixtures/console.res
```

The first diagnostic is `test/fixtures/console.res:1:1: error [no-console] Do not use Console.log.`; this fixture exits with code `1`.

`no-console` recognizes standard console references through known module aliases and opens/includes, including pipes, callbacks, and value captures such as `let log = Console.log`. It respects lexical shadows and configured project module names. Unknown exports, custom JavaScript bindings and arbitrary cross-file value aliases remain outside this bounded analysis. See [the shared resolution contract](docs/RULES.md#shared-api-resolution) before using it as an enforcement gate.

`no-object-magic` bans `Obj.magic`, `Primitive_object.magic`, and `Primitive_object_extern.magic`, including references captured as values. In the pinned runtime, the unchecked cast is called `Obj.magic`; `Object.magic` is not a standard API.

`no-unsafe` bans an [explicit inventory](docs/UNSAFE_APIS.md) of unsafe APIs from the pinned standard library, `Js`, and `Belt`. Both `Option.getUnsafe(None)` and `Option.getUnsafe(Some(value))` fail, even inside try/catch or an exception switch. Qualified references captured as values also fail. Unrelated custom functions are not banned just because their names contain `Unsafe`.

The three banned-API rules use one traversal with the same shadowing checks and resolution limits. Try `opam exec -- dune exec rescript-lint -- test/fixtures/unsafe.res` to see them together.

`react/rules-of-hooks` checks calls named `use` followed by an uppercase ASCII letter or digit, qualified or unqualified. Hooks belong in annotated component bodies or named custom hooks, not ordinary functions, callbacks, module initializers, branches, loops, or exception handlers. It also rejects hooks in async functions and default arguments. Bare `use` and `React.use` allow branches and loops but still require a valid function context and cannot appear in exception-handling regions.

The hooks rule has its own contextual traversal. It supports multi-parameter functions and annotated components wrapped in `React.memo`/`React.forwardRef`. It does not resolve hook aliases or symbol identity, analyze every execution path, or check dependency arrays. Recognition is based on source spelling, not installed React bindings. See [the implemented scope](docs/RULES.md#reactrules-of-hooks) for exceptions and limitations. Try `opam exec -- dune exec rescript-lint -- test/fixtures/hooks.res` for failures or `test/fixtures/hooks_clean.res` for a passing example.

`no-unhandled-throws` requires handling for resolved local or configured-project `@throws` and legacy `@raises` functions, including simple value/module aliases and externals. It accepts applicable unguarded catches or switch exception patterns. Caller annotations and `@doesNotThrow` never discharge a call. Bare `@throws` requires a catch-all; guarded and payload-specific patterns are insufficient to cover an entire declared exception.

With `--project DIR` or a configured root, throws analysis also resolves project-local imported contracts, giving `.resi` declarations precedence over implementation exports. Unannotated callers are checked when they depend on annotated modules; aliases and matching implementation/interface exception identities are preserved. Without a project root or runtime adapter, activation remains source-local. In active files, unresolved qualified references, malformed metadata and unsupported async/contract escapes produce `throws-analysis` errors (exit `2`), not a clean result. See [the exact boundary](docs/THROWS.md).

`--throws-runtime rescript-12.3.1` (or `"throwsRuntime": "rescript-12.3.1"` in configuration) explicitly activates every requested file and adds nine verified JSON runtime contracts. These bare annotations require catch-all handling. Other public runtime names become resolvable but are not proven non-throwing. Dependency packages and arbitrary effects are not inferred; default activation is unchanged.

Try `opam exec -- dune exec rescript-lint -- test/fixtures/throws.res` for unhandled calls, `test/fixtures/throws_clean.res` for both handling forms, or `test/fixtures/throws_unsupported.res` for an explicit analysis failure.

The control-flow pass implements `no-constant-condition`,
`no-constant-binary-expression`, `no-duplicate-condition`, and
`no-identical-branches`. It folds only boolean literals and literal comparisons,
compares duplicate conditions only when their syntax is stable, and compares
adjacent branch ASTs without treating comments as behavior. Function calls and
potentially mutable reads are not assumed stable. These rules have no automatic
fixes. Findings from all enabled rule subsets appear in source order.

`no-debugger` reports executable debugger expressions. `no-useless-catch`
reports handlers that only rethrow their unchanged caught exception. Ten further
syntax policies are opt-in: `no-catch-all-exception`,
`simplify-boolean-expression`, `no-useless-concat`, `approx-constant`,
`no-empty-function`, `no-empty-file`, `no-warning-comments`, `max-nesting`,
`max-params`, and `max-lines-per-function`. For example,
`rescript-lint --enable-rule no-empty-function src/Example.res` checks empty
callbacks alongside the default rules. See [contracts and examples](docs/SYNTAX_RULES.md).

`blank-lines` requires blank separators after externals and pipe statements/bindings, before annotated value bindings, and around switch statements/bindings. It supports nested blocks, signatures, and JSX sibling expressions. It does not pad block/file boundaries or arbitrary inline expressions. `rescript-lint --fix src/Example.res` applies minimal spacing edits, checks them against the pinned formatter, and reports remaining errors. Files with parse/analysis failures are left unchanged. See [the autofix contract](docs/BLANK_LINES.md) for safety checks and formatter-compatibility limits.

Exit codes: `0` clean/help/version, `1` remaining lint findings, `2` usage, input, analysis, fix, or write failures. The runner continues after file errors, with failures taking precedence over findings. Syntax errors go to stderr; lint findings go to stdout. No rules run on a recovered invalid parse tree. Diagnostics use one-based lines and UTF-8 byte columns, with zero-based byte offsets and exclusive range ends internally.
