# @jvlk/rescript-lint

A native ReScript linter using the official ReScript 12.3.1 parser, with 105
registered rules: twelve defaults and 93 opt-in rules.

This is an early alpha release. Native platform and source-bundle checks pass on
the tagged release commit before publication.

## Install

Requires Node.js 24+ and npm with optional dependencies enabled. No OCaml, Dune,
or ReScript project build is needed for syntax checks. The optional unused-export
rule requires fresh compiler artifacts and a Reanalyze report.

```sh
npm install --save-dev @jvlk/rescript-lint@alpha
npx rescript-lint src/Example.res src/Example.resi
npx rescript-lint --watch src/Example.res src/Example.resi
npx rescript-lint --fix src/Example.res
npx rescript-lint lsp --stdio
npx rescript-lint --config rescript-lint.json
npx rescript-lint --jsx-runtime react-dom --enable-rule jsx-a11y/alt-text src/View.res
```

This release is published on the `alpha` dist-tag. Supply file paths, or use
`--project DIR` to discover sources from that project's `rescript.json`. Shell
globs depend on the shell; the linter does not expand them.

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

Native targets for this release are Linux glibc x64 and ARM64. The configured
build baseline is Ubuntu 22.04; older glibc versions are not guaranteed. macOS,
Windows, Alpine/musl, and 32-bit systems are not supported in this alpha.

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
## Structured Output and Project Updates

Use `--format json` for versioned findings, structured errors and exact byte
ranges/fixes. Watch writes one JSON object per pass to stdout and status messages
to stderr. Human output remains the default; exit codes are unchanged.

Watch rediscovers project sources and observes declaration/configuration changes,
including explicit dependency contracts. Unchanged project syntax trees are
reused using content equality, while diagnostics and metadata are recomputed.

With a configured project root, `throwsDependencies` selects explicit package
paths relative to the lint configuration. Public interfaces and supported
namespaces are respected; unsupported package layouts fail rather than silently
omitting contracts. `warningComments` configures terms and allowed parsed comment
contexts for the opt-in warning-comment rule. See the repository's JSON,
exception-contract and syntax-rule references for exact boundaries.
