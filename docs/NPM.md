# npm Packaging

## Current status

The intended public package is **`@jvlk/rescript-lint`**, providing the
**`rescript-lint`** command. Packaging is implemented; publishing is deliberately
disabled. Both the main and generated native manifests contain `private: true`.
Nothing has been published to npm. The authenticated account's ownership of the
`@jvlk` organization was verified on 2026-09-20; all six package names returned
HTTP 404. These checks do not reserve names. The project's original code is MIT-licensed;
native packages include third-party licenses and corresponding source as described
in [the distribution notes](DISTRIBUTION.md).

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

Both package types include the project's MIT `LICENSE` and `DISTRIBUTION.md`.
Their README comes from `npm/README.md`, with user-facing CLI documentation and
absolute repository links that work outside the checkout.
The launcher declares `MIT`; native manifests use `SEE LICENSE IN DISTRIBUTION.md`
to distinguish our code's license from the bundled dependencies' licenses.
Native packages also contain `third-party/`: eight checksum-pinned upstream source
archives, extracted license/notice files, the application source, and instructions
for rebuilding/relinking. The bundle is roughly 20 MB before npm compression.

Prefix each suffix with `@jvlk/rescript-lint-`. Native manifests declare npm
`os` and `cpu` constraints, plus `libc: ["glibc"]` on Linux. npm installs the
matching optional dependency. The launcher detects the Node process OS/CPU
and Linux libc, resolves that package, checks its name/version, then starts
the binary without a shell. It inherits stdin/stdout/stderr and preserves
native exit codes; SIGINT/SIGTERM are forwarded and native signal termination
is propagated. Installation with `--omit=optional` produces an actionable
launcher error, not a fallback network download.

All four targets passed hosted builds and pack/install tests on `98e7e4d`:
[beta preparation CI](https://github.com/jderochervlk/rescript-lint/actions/runs/35540592523).
The workflow as a whole failed on Windows, which is now deferred from the first
release. The four supported targets must pass again on the exact release commit.
The Linux baseline is the Ubuntu 22.04 build environment; older glibc
versions are not guaranteed. macOS builds currently target the macOS 15 build
environment; no older deployment target is promised. Windows, Alpine/musl, and
32-bit systems are not supported in this release.

## Local checks

From the repository root, with the existing Opam switch and Node 24+:

```sh
opam exec -- dune build --profile release @install
npm run prepare:licenses
npm test
npm run test:rebuild
npm run pack:native
npm run test:package
```

No `npm install` is needed for repository tooling. `npm test` runs Node's native
test runner, checks launcher/packaging behavior, and packs the current host's
release binary. It needs that binary and its license/source bundle prepared first.
Preparation needs Git, Opam, tar with gzip/bzip2 support, and network access for
checksum-pinned source downloads on the first run. Rerun it after changing native
sources or rebuilding the binary. No downloads happen on consumer installation.
Coverage requires at least
90% lines, branches, and functions per source file and overall, and every own
packaging/launcher source must appear in the report. Node's coverage report does
not provide a separate statement metric. POSIX signal integration tests do not
run on Windows; signal dispatch is also covered through its process boundary.

`npm run pack:native -- /absolute/path/to/binary` can select a different input
binary. It must match the binary hash recorded by license preparation, run on the
current host, and report exactly the
version in `npm/package.json`; cross-packing is intentionally not supported.
Keep that version aligned with `lib/command.ml` and `dune-project`. The build
fails on executable/npm version drift instead of producing a mislabeled package.

Each run creates fresh staging directories under ignored `dist/npm/<target>/`.
The two tarballs are written alongside them. Only explicit package files are
included, never `_opam`, `_build`, or the Git checkout. Native source archives
include upstream tests and notices; our application archive is restricted to
native sources and build definitions. Use the
generated tarballs, not `npm pack ./npm`: the source manifest is a template and
does not yet contain its generated optional dependencies.

The smoke test installs both tarballs offline into a temporary project outside
the repository, with lifecycle scripts disabled. It exercises the installed npm
bin shim, help/version, successful linting, findings, syntax/input/usage errors,
and filenames containing spaces. It runs with a reduced PATH that excludes the
Opam toolchain, catching accidental reliance on build-environment DLLs/tools.
It is not a complete dynamic-library or minimum-OS compatibility audit.

## CI and release follow-up

`.github/workflows/npm.yml` runs the four native builds on PRs, pushes to main,
and manual dispatch. It builds and tests OCaml in release mode, prepares the
license/source bundle, verifies rebuilding with a modified library, enforces Node
test coverage, checks the actual runner target, packs both packages, and tests
the installation. Existing OCaml formatting/coverage CI remains unchanged.

The workflow has read-only repository permissions and no publishing credentials,
publication steps, or binary uploads. Before enabling publication:

1. Require the [license/source bundle checks](DISTRIBUTION.md) on each release
   target. Re-audit changed dependencies; do not remove the bundle from tarballs.
2. Verify all four builds and audit native dependencies on clean machines.
   Confirm the oldest supported OS/libc versions.
3. Recheck ownership of the `@jvlk` scope and availability of the five active package names.
4. Use the approved `0.1.0-beta.1` version and `beta` dist-tag; remove the publication
   guards only after the source-bundle and platform checks are complete.
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

## Deferred Windows target

Windows is not in `npm/targets.json`, so CI and the launcher's optional
dependencies do not include it. The retained Windows-specific launcher/smoke
test scaffolding is not a support guarantee. Before reintroducing the target,
resolve the fixture byte-comparison failures in `application_test`, confirm
checkout line endings without weakening CRLF preservation tests, and audit
DLL dependencies outside the Opam/Cygwin environment. Its former target was
`win32-x64`, runner `windows-2022`, binary `rescript-lint.exe`.
