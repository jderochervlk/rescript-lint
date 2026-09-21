# @jvlk/rescript-lint

A native ReScript linter using the official ReScript 12.3.1 parser, with 105
registered rules: twelve defaults and 93 opt-in rules.

**Release preparation:** this package is not published yet. The installation
commands below apply after the first release. Native platform and source-bundle
checks must pass on the release commit before publication.

## Install

Requires Node.js 24+ and npm with optional dependencies enabled. No OCaml, Dune,
or ReScript project build is needed for syntax checks. The optional unused-export
rule requires fresh compiler artifacts and a Reanalyze report.

```sh
npm install --save-dev @jvlk/rescript-lint@beta
npx rescript-lint src/Example.res src/Example.resi
npx rescript-lint --watch src/Example.res src/Example.resi
npx rescript-lint --fix src/Example.res
npx rescript-lint lsp --stdio
npx rescript-lint --config rescript-lint.json
npx rescript-lint --jsx-runtime react-dom --enable-rule jsx-a11y/alt-text src/View.res
```

The planned first release is `0.1.0-beta.1` on the `beta` dist-tag, not `latest`.
Supply file paths, or use `--project DIR` to discover sources from that project's
`rescript.json`. Shell globs depend on the shell; the linter does not expand them.

```text
rescript-lint [--fix] [--watch] [--config FILE] [--project DIR] [--] FILE.res [FILE.resi ...]
rescript-lint lsp --stdio
```

`--help` and `--version` are standalone options. `--` allows filenames beginning
with a hyphen. `--list-rules` lists exact IDs and defaults. Repeat
`--enable-rule ID` or `--disable-rule ID` to select rules; the last setting wins.
JSON configuration also controls adapters, project policies and rule limits.

`--watch` (or `-w`) runs immediately and reruns the full initial file set after
changes. Findings and file or analysis failures do not stop it. Press Ctrl+C to
stop watching. Project discovery selects the initial watched set; restart watch
after adding source files.

`lsp --stdio` is intended for editor clients. It publishes diagnostics for open,
unsaved `.res` and `.resi` documents using full-document synchronization. It does
not replace ReScript's compiler-backed language server for completion,
navigation, or type information.

## Rules

These twelve rules are enabled by default:

| Rule | Current scope |
| --- | --- |
| `no-console` | Resolved standard console references, including module aliases and opens |
| `no-object-magic` | Standard unchecked casts such as `Obj.magic` |
| `no-unsafe` | An explicit inventory of standard unsafe APIs, including `getUnsafe` |
| `react/rules-of-hooks` | Basic hook placement; not dependency-array or complete control-flow analysis |
| `no-unhandled-throws` | Local/project contracts, plus opt-in pinned JSON runtime contracts |
| `blank-lines` | Separators around selected declarations, pipes, and switches; supports `--fix` |
| `no-constant-condition` | Safely folded constant conditions |
| `no-constant-binary-expression` | Boolean and comparison expressions with fixed results |
| `no-duplicate-condition` | Repeated stable branch conditions |
| `no-identical-branches` | Equivalent adjacent branch bodies with binding checks |
| `no-debugger` | Executable debugger expressions |
| `no-useless-catch` | Handlers that only rethrow the unchanged exception |

Optional packs add ten syntax policies, twenty semantic/API rules, 34 JSX
accessibility rules, twelve React rules, twelve test rules and five project
policies. JSX/React additions require `--jsx-runtime react-dom`; test rules
require `--test-framework rescript-vitest-3`. Missing adapters and required
metadata produce analysis errors. The existing rules-of-hooks default remains
a separate syntax check.

See the [extended reference](https://github.com/jderochervlk/rescript-lint/blob/main/docs/EXTENDED_RULES.md)
for exact activation, JSON examples, metadata freshness, conservative analysis
limits and audited inline suppressions. New optional rules do not add automatic
semantic rewrites.

These checks have deliberate limits. Banned APIs resolve known module aliases,
opens/includes and configured project shadows using pinned public export shapes.
Unknown exports and arbitrary cross-file value aliases are not inferred.
With a project root, the throws rule resolves
project-local imported declarations and pairs `.res`/`.resi` exception identities;
without one or a runtime adapter, it retains source-local activation.
`--throws-runtime rescript-12.3.1` (configuration `throwsRuntime`) opts every
requested file into runtime-aware checking and adds nine verified JSON contracts
requiring catch-all handling. Other runtime exports are not proven non-throwing.
It does not discover dependency packages or infer arbitrary effects. Unsupported active
throws analysis produces an analysis error.
Read the [rule contracts](https://github.com/jderochervlk/rescript-lint/blob/main/docs/RULES.md)
and [throws limitations](https://github.com/jderochervlk/rescript-lint/blob/main/docs/THROWS.md)
before relying on these checks as an enforcement gate.

`--fix` applies only spacing changes. It validates the resulting source and
checks spacing against the pinned formatter before writing. Parse or analysis
failures leave that file unchanged. Remaining findings still fail the command.
See the [autofix contract](https://github.com/jderochervlk/rescript-lint/blob/main/docs/BLANK_LINES.md).

## Results

Diagnostics use `path:line:column: error [rule] message`, with one-based lines
and UTF-8 byte columns. Findings go to stdout; analysis failures go to stderr.

| Exit code | Meaning |
| --- | --- |
| `0` | Clean input, help, or version |
| `1` | Remaining lint findings |
| `2` | Usage, input, parse, analysis, fix, or write failure |

All requested files are processed. Failures take precedence over findings.

## Platforms

Native targets for the first release are Linux glibc x64/ARM64 and macOS
Intel/Apple Silicon. All four passed hosted build and package-install checks on
the beta preparation commit. The configured build baselines are Ubuntu 22.04
and macOS 15; older OS versions are not guaranteed. Windows is deferred to a
later release. Alpine/musl and 32-bit systems are not supported.

Install `@jvlk/rescript-lint`, not a platform-specific package directly. npm
selects the native optional dependency for the Node process architecture.
Do not use `--omit=optional`; missing native packages produce a launcher error.
There are no install-time download scripts.

## License and Source

Original linter and launcher code is MIT-licensed. The native executable also
contains third-party code under other licenses. See `LICENSE` and
`DISTRIBUTION.md` in this package. The installed native package includes license
texts and full library/application source archives under `third-party/`, with
instructions for rebuilding and relinking against modified libraries.

[Source and issues](https://github.com/jderochervlk/rescript-lint)

The repository README covers building from source and contributing.
