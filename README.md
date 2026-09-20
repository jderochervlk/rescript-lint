# ReScript Linter

An extensible linter for [ReScript](https://rescript-lang.org/).

An early, working OCaml CLI with the official ReScript 12.3.1 parser and the `no-console`, `no-object-magic`, and `no-unsafe` rules. It parses `.res` and `.resi` files directly, without running a compiler subprocess or requiring a project build.

## Current direction

Use OCaml with the official ReScript parser/AST. The pinned compiler checkout and build adapter are documented in [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md), including upstream licenses and upgrade steps.

Keep diagnostics and command behavior independent of compiler types; avoid designing a replacement AST before the rules need it.

## Project plan

See [docs/PLAN.md](docs/PLAN.md) for milestones, boundaries, and open questions. The language choice is recorded in [docs/decisions/001-implementation-language.md](docs/decisions/001-implementation-language.md).

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

Edit `dune-project` for package metadata. `make check` detects changes to the generated Opam file; after that check, run `opam exec -- dune promote rescript_linter.opam` to update it. Homepage, issue tracker, and license metadata remain unset until the repository is published and a license is selected.

## Coverage

The published Bisect package and its main branch do not build with the PPX version required by OCaml 5.5. Development coverage uses the pinned compatibility commit from [Bisect PR 448](https://github.com/aantron/bisect_ppx/pull/448). This is an unmerged tooling workaround, not a runtime dependency.

```sh
make coverage-tools
make coverage
```

Each run writes fresh data and an HTML report under `_coverage/`. The check requires all `lib/` and `bin/` implementation files in the report and at least 90% execution-point coverage per file and overall; aim for 100%. Bisect measures instrumented execution points, not separate statement/branch/function/line percentages. Tests themselves are not instrumented.

## CLI contract

`rescript-lint [--] FILE.res [FILE.resi ...]` accepts explicit file paths in argument order. Help and version are available as standalone options. Directory discovery, JSON output, configuration, and the remaining rules are planned work.

```sh
opam exec -- dune exec rescript-lint -- test/fixtures/console.res
```

The first diagnostic is `test/fixtures/console.res:1:1: error [no-console] Do not use Console.log.`; this fixture exits with code `1`.

`no-console` recognizes qualified standard console references, including pipes, callbacks, and value aliases such as `let log = Console.log`. It skips comments, strings, annotation payloads, and basic local module shadows. This is syntax-only analysis: module aliases, opens/includes, project-defined modules, and custom JavaScript bindings are not resolved. See [the rule's scope](docs/RULES.md#no-console) before using it as an enforcement gate.

`no-object-magic` bans `Obj.magic`, `Primitive_object.magic`, and `Primitive_object_extern.magic`, including references captured as values. In the pinned runtime, the unchecked cast is called `Obj.magic`; `Object.magic` is not a standard API.

`no-unsafe` bans an [explicit inventory](docs/UNSAFE_APIS.md) of unsafe APIs from the pinned standard library, `Js`, and `Belt`. Both `Option.getUnsafe(None)` and `Option.getUnsafe(Some(value))` fail, even inside try/catch or an exception switch. Qualified references captured as values also fail. Unrelated custom functions are not banned just because their names contain `Unsafe`.

All three rules use one traversal with the same shadowing checks and resolution limits. Findings appear in source order. Try `opam exec -- dune exec rescript-lint -- test/fixtures/unsafe.res` to see all three rules together.

Exit codes: `0` clean/help/version, `1` lint findings, `2` usage, input, or analysis failures. The runner continues after file errors, with failures taking precedence over findings. Syntax errors go to stderr; lint findings go to stdout. No rules run on a recovered invalid parse tree. Diagnostics use one-based lines and UTF-8 byte columns, with zero-based byte offsets and exclusive range ends internally.
