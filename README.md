# ReScript Linter

A native linter for [ReScript](https://rescript-lang.org/). It checks `.res`
and `.resi` source directly, without requiring an OCaml toolchain or a ReScript
build for syntax rules.

This is an early alpha release. It includes 123 rules: 12 enabled by default
and 111 opt-in rules for syntax, bounded semantic analysis, React/DOM
accessibility, tests, and project policies.

## Install

Install the linter as a development dependency. It requires Node.js 24 or
newer and npm optional dependencies to be enabled.

```sh
npm install --save-dev @jvlk/rescript-lint@alpha
```

The package includes a prebuilt native executable, so consumers do not need
OCaml, Opam, Dune, or a compiler checkout. This alpha supports Linux glibc x64
and ARM64 only. macOS, Windows, Alpine/musl, and 32-bit systems are not yet
supported. Do not install a platform-specific package directly or use
`--omit=optional`.

## Use

Lint explicit files:

```sh
npx rescript-lint src/Main.res src/Api.resi
```

Or lint a project. With no file arguments, `--project` discovers source files
from that directory's `rescript.json`:

```sh
npx rescript-lint --project .
```

Common day-to-day commands:

```sh
npx rescript-lint --watch --project .
npx rescript-lint --fix src/Main.res
npx rescript-lint --list-rules
npx rescript-lint --format json --project .
```

`--fix` currently applies validated spacing fixes only. `--watch` runs once,
then reruns after relevant source or configuration changes. `--format json`
emits one versioned JSON result per run, which is useful for CI integrations.

Add a script for routine use:

```json
{
  "scripts": {
    "lint": "rescript-lint --project ."
  }
}
```

Then run `npm run lint`. A clean run exits `0`, lint findings exit `1`, and
usage, input, parsing, analysis, fix, or write failures exit `2`.

## Configure

Pass a JSON configuration file with `--config`. Paths in the file are relative
to that file, except `exclude`, whose entries are relative to the configured
`root`. For a config in `config/` with `"root": ".."`, use
`"exclude": ["src/generated"]`, not `"../src/generated"`.

```json
{
  "root": ".",
  "jsxRuntime": "react-dom",
  "rules": {
    "jsx-a11y/alt-text": true,
    "react/jsx-key": true,
    "no-warning-comments": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json
```

Use `--enable-rule ID` and `--disable-rule ID` for command-specific rule
selection; later settings win. Optional JSX and React rules require
`"jsxRuntime": "react-dom"`; test rules require
`"testFramework": "rescript-vitest-3"`. The complete configuration format,
adapters, per-file overrides, suppressions, project settings, and rule limits
are in the [extended rule reference](docs/EXTENDED_RULES.md).

Use `--inspect-config src/Main.res --config rescript-lint.json --format json`
to inspect effective per-file rules, origins, options, and adapter requirements
without reading or linting the source. The npm package ships `config.schema.json`;
use `"$schema": "./node_modules/@jvlk/rescript-lint/config.schema.json"` for editor
completion. See [configuration inspection and restriction policies](docs/CONFIGURATION.md).

## Rules And Editors

The default rules cover console calls, unchecked casts and unsafe APIs, React
hook placement, unhandled throws contracts, selected blank-line spacing,
constant or duplicate conditions, identical branches, debugger expressions, and
useless catch handlers. Run `rescript-lint --list-rules` for the authoritative
rule inventory and defaults.

Read the [rule contracts](docs/RULES.md), [syntax-rule reference](docs/SYNTAX_RULES.md),
and [throws-analysis boundaries](docs/THROWS.md) before using optional rules as
an enforcement gate. The [JSON diagnostics schema](docs/JSON_DIAGNOSTICS.md)
documents structured output precisely. The [newest policy contracts](docs/POLICY_EXPANSION.md)
cover the 18 additional opt-in rules.

For editor clients, start the language server over stdio:

```sh
npx rescript-lint lsp --stdio
```

It publishes diagnostics for open `.res` and `.resi` buffers. It complements,
rather than replaces, ReScript's compiler-backed language server for completion,
navigation, and type information.

## License

The linter and launcher are [MIT licensed](LICENSE). The native executable also
contains third-party code under other licenses; see
[distribution details](docs/DISTRIBUTION.md) and the license material included
with installed packages.

## Contributing

Development setup, validation, coverage, packaging, CI, and release guidance
live in [CONTRIBUTING.md](CONTRIBUTING.md).
