# @jvlk/rescript-lint

A native ReScript linter using the official ReScript 12.3.1 parser.

**Release preparation:** this package is not published yet. The installation
commands below apply after the first release. Native platform and source-bundle
checks must pass on the release commit before publication.

## Install

Requires Node.js 24+ and npm with optional dependencies enabled. No OCaml, Dune,
or ReScript project build is needed to run the packaged executable.

```sh
npm install --save-dev @jvlk/rescript-lint@beta
npx rescript-lint src/Example.res src/Example.resi
npx rescript-lint --watch src/Example.res src/Example.resi
npx rescript-lint --fix src/Example.res
```

The planned first release is `0.1.0-beta.1` on the `beta` dist-tag, not `latest`.
Supply file paths, not directories. Shell globs
depend on the shell; the linter does not expand them or discover project files.

```text
rescript-lint [--fix] [--watch] [--] FILE.res [FILE.resi ...]
```

`--help` and `--version` are standalone options. `--` allows filenames beginning
with a hyphen. All rules are enabled; configuration and rule selection are not
implemented yet.

`--watch` (or `-w`) runs immediately and reruns the full explicit file set after
changes. Findings and file or analysis failures do not stop it. Press Ctrl+C to
stop watching. Directory inputs and recursive discovery are not implemented yet.

## Rules

| Rule | Current scope |
| --- | --- |
| `no-console` | Qualified standard console references, including value aliases |
| `no-object-magic` | Standard unchecked casts such as `Obj.magic` |
| `no-unsafe` | An explicit inventory of standard unsafe APIs, including `getUnsafe` |
| `react/rules-of-hooks` | Basic hook placement; not dependency-array or complete control-flow analysis |
| `no-unhandled-throws` | Handling of same-file `@throws` and legacy `@raises` contracts |
| `blank-lines` | Separators around selected declarations, pipes, and switches; supports `--fix` |

These checks have deliberate limits. Qualified-reference checks do not resolve
every module alias or open. The throws rule is **not project-wide** and does not
enforce imported exception contracts or combine `.res` and `.resi` declarations.
Unsupported throws analysis in annotated files can produce an analysis error.
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
