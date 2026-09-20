# npm Packaging

## Current status

The intended public package is **`@jvlk/rescript-lint`**, providing the
**`rescript-lint`** command. Packaging is implemented; publishing is deliberately
disabled. Both the main and generated native manifests contain `private: true`.
Nothing has been published to npm. The authenticated account's ownership of the
`@jvlk` organization was verified on 2026-09-20; all six package names returned
HTTP 404. These checks do not reserve names. The project's original code is MIT-licensed; upstream redistribution
requirements still need review.

Consumers will need Node.js 24 or newer and npm with optional dependencies
enabled, but no OCaml, Opam, Dune, compiler checkout, or project build. Node 24
is the current tested launcher/tooling baseline, not a claim that the native
linter itself requires Node. There are no third-party JavaScript dependencies
or install-time download scripts.

## Package layout

`npm/package.json` is the source main-package manifest. `npm/targets.json` is
shared by the launcher, package generator, tests, and CI matrix. Generated
manifests add exact-version optional dependencies on these packages:

| Native package suffix | OS / CPU | Build runner |
| --- | --- | --- |
| `linux-x64-gnu` | Linux glibc / x64 | `ubuntu-22.04` |
| `linux-arm64-gnu` | Linux glibc / ARM64 | `ubuntu-22.04-arm` |
| `darwin-x64` | macOS / Intel | `macos-15-intel` |
| `darwin-arm64` | macOS / Apple Silicon | `macos-15` |
| `win32-x64` | Windows / x64 | `windows-2022` |

Both package types include the project's MIT `LICENSE` and `DISTRIBUTION.md`.
Their README comes from `npm/README.md`, with user-facing CLI documentation and
absolute repository links that work outside the checkout.
The launcher declares `MIT`; native manifests use `SEE LICENSE IN DISTRIBUTION.md`
to distinguish our code's license from the bundled dependencies' licenses.

Prefix each suffix with `@jvlk/rescript-lint-`. Native manifests declare npm
`os` and `cpu` constraints, plus `libc: ["glibc"]` on Linux. npm installs the
matching optional dependency. The launcher detects the Node process OS/CPU
and Linux libc, resolves that package, checks its name/version, then starts
the binary without a shell. It inherits stdin/stdout/stderr and preserves
native exit codes; SIGINT/SIGTERM are forwarded and native signal termination
is propagated. Installation with `--omit=optional` produces an actionable
launcher error, not a fallback network download.

These are configured targets, not yet five verified releases. Local Linux x64
pack/install tests pass. All five hosted builds must pass before advertising
support. The Linux baseline is the Ubuntu 22.04 build environment; older glibc
versions are not guaranteed. macOS builds currently target the macOS 15 build
environment; no older deployment target is promised. Windows desktop and
minimum OS compatibility need additional testing beyond the Server 2022 runner.
Alpine/musl, Windows ARM64, and 32-bit systems are not supported yet.

## Local checks

From the repository root, with the existing Opam switch and Node 24+:

```sh
opam exec -- dune build --profile release @install
npm test
npm run pack:native
npm run test:package
```

No `npm install` is needed for repository tooling. `npm test` runs Node's native
test runner, checks launcher/packaging behavior, and packs the current host's
release binary. It needs that binary built first. Coverage requires at least
90% lines, branches, and functions per source file and overall, and every own
packaging/launcher source must appear in the report. Node's coverage report does
not provide a separate statement metric. POSIX signal integration tests do not
run on Windows; signal dispatch is also covered through its process boundary.

`npm run pack:native -- /absolute/path/to/binary` can select a different input
binary. The executable must run on the current host and report exactly the
version in `npm/package.json`; cross-packing is intentionally not supported.
Keep that version aligned with `lib/command.ml` and `dune-project`. The build
fails on executable/npm version drift instead of producing a mislabeled package.

Each run creates fresh staging directories under ignored `dist/npm/<target>/`.
The two tarballs are written alongside them. Only explicit package files are
included, never `_opam`, `_build`, source tests, or the Git checkout. Use the
generated tarballs, not `npm pack ./npm`: the source manifest is a template and
does not yet contain its generated optional dependencies.

The smoke test installs both tarballs offline into a temporary project outside
the repository, with lifecycle scripts disabled. It exercises the installed npm
bin shim, help/version, successful linting, findings, syntax/input/usage errors,
and filenames containing spaces. It runs with a reduced PATH that excludes the
Opam toolchain, catching accidental reliance on build-environment DLLs/tools.
It is not a complete dynamic-library or minimum-OS compatibility audit.

## CI and release follow-up

`.github/workflows/npm.yml` runs the five native builds on PRs, pushes to main,
and manual dispatch. It builds and tests OCaml in release mode, enforces Node
test coverage, checks the actual runner target, packs both packages, and tests
the installation. Existing OCaml formatting/coverage CI remains unchanged.

The workflow has read-only repository permissions and no publishing credentials,
publication steps, or binary uploads. Before enabling publication:

1. Complete [the upstream distribution review](DISTRIBUTION.md).
   Include required license texts/notices and satisfy any source obligations
   in every distributable package. `DISTRIBUTION.md` alone is not sufficient.
2. Verify all five builds and audit native dependencies on clean machines.
   Confirm the oldest supported OS/libc versions, particularly Windows DLLs.
3. Recheck ownership of the `@jvlk` scope and availability of all six package names.
4. Pick an initial prerelease version and remove the publication guards only
   after the licensing and platform checks are complete.
5. Add a tag/manual release workflow with protected approval, pinned tooling,
   artifact integrity checks, and npm trusted publishing (OIDC) per package.
   Handle initial package creation/registry setup separately as needed.
6. Publish all native packages at the same exact version first, verify their
   availability, then publish the main package last. Test a real registry install.

See [the release runbook](RELEASING.md) for the verified registry preflight,
approval gates, proposed trusted-publisher settings, and partial-release recovery.

References: [npm package metadata](https://docs.npmjs.com/cli/v11/configuring-npm/package-json/),
[npm trusted publishing](https://docs.npmjs.com/trusted-publishers/),
[GitHub runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
