# Contributing To ReScript Linter

Thanks for contributing. The repository builds an OCaml CLI around the pinned
official ReScript parser. Consumer installation and usage belong in the
[README](README.md); this guide covers working on the linter itself.

## Development Setup

Install and initialize [Opam](https://opam.ocaml.org/doc/Install.html), then
create the repository-local switch and install development dependencies:

```sh
git submodule update --init
opam switch create . 5.5.0 --no-install
opam install . --deps-only --with-dev-setup --yes
make check
opam exec -- dune exec rescript-lint -- --help
```

The project requires Opam 2.2 or newer, OCaml 5.5.0, Dune 3.24.2, and
OCamlformat 0.29.0. `opam exec` selects the local `_opam` switch without
changing shell configuration.

## Validate Changes

Run the narrowest relevant check while iterating, then run the full check before
opening a pull request:

```sh
make build       # Compile the library and CLI; enabled warnings are fatal
make test        # Unit tests and CLI fixtures
make format      # Apply OCamlformat and Dune formatting
make check       # Build, formatting check, and tests
```

Changes to `dune-project` package metadata can alter the generated
`rescript_linter.opam`. After `make check` reports the drift, update it with:

```sh
opam exec -- dune promote rescript_linter.opam
```

Coverage uses a pinned Bisect compatibility commit because published Bisect
does not currently build with the required OCaml 5.5 PPX combination:

```sh
make coverage-tools
make coverage
```

This writes an HTML report under `_coverage/`. The gate requires every `lib/`
and `bin/` implementation file to be present and at least 90% execution-point
coverage per file and overall; aim for 100%.

## Project Context

The CLI uses the official ReScript parser/AST, while diagnostics and command
behavior remain independent from compiler types. The pinned compiler checkout,
build adapter, licenses, and upgrade boundary are documented in
[docs/DEPENDENCIES.md](docs/DEPENDENCIES.md). The roadmap and open questions are
in [docs/PLAN.md](docs/PLAN.md); language-server work is tracked in
[docs/LSP.md](docs/LSP.md).

Keep rule changes grounded in their documented contracts and add focused tests
for supported behavior, edge cases, and explicit unsupported boundaries. The
[rule references](docs/RULES.md), [extended rule reference](docs/EXTENDED_RULES.md),
and adjacent test fixtures are the best starting points.

## npm Packaging And Releases

The published package is `@jvlk/rescript-lint`, with Linux glibc x64 and ARM64
native packages in this alpha. Packaging includes third-party license material
and rebuildable source bundles. Repository packaging commands require Node.js
24 or newer:

```sh
npm run prepare:licenses
npm test
npm run test:rebuild
npm run pack:native
npm run test:package
```

The [npm packaging guide](docs/NPM.md) explains the package layout, verification
and compatibility boundaries. Follow [the release guide](docs/RELEASING.md) for
version updates, trusted publishing, tag creation, and partial-release handling.

## CI

[GitHub Actions](.github/workflows/ci.yml) runs the OCaml checks on pull
requests, pushes to `main`, and manual dispatch. It runs `make check`, verifies
generated Opam metadata, builds the release package, and enforces the coverage
gate. The npm workflow builds and verifies both Linux packages. Workflow details
and release publishing live in [`.github/workflows`](.github/workflows).

## License

Original project code is [MIT licensed](LICENSE), Copyright (c) 2026 Josh Vlk.
Third-party sources and linked dependencies retain their own licenses, including
LGPL provisions and linking exceptions. See [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md)
and [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) for the distribution boundary.
