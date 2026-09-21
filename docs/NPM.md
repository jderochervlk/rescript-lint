# npm Packaging

## Current status

The public package is **`@jvlk/rescript-lint`**, providing the
**`rescript-lint`** command. Its Linux glibc x64 and ARM64 native packages are
published on npm. The project's original code is MIT-licensed; native packages
include third-party licenses and corresponding source as described in [the
distribution notes](DISTRIBUTION.md).

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

Both Linux targets passed hosted builds and pack/install tests on the
`v0.1.0-alpha.1` release tag. They must pass again on every exact release tag.
The Linux baseline is Ubuntu 22.04; older glibc versions are not guaranteed. macOS, Windows,
Alpine/musl, and 32-bit systems are deferred from this alpha.

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

`.github/workflows/npm.yml` runs the two Linux native builds on PRs, pushes to
main, and manual dispatch. It builds and tests OCaml in release mode, prepares the
license/source bundle, verifies rebuilding with a modified library, enforces Node
test coverage, checks the actual runner target, packs both packages, and tests
the installation. Existing OCaml formatting/coverage CI remains unchanged.

`.github/workflows/release.yml` runs for a `v*` tag or a manual build-only
dispatch. It rebuilds and tests both Linux targets, archives their verified
tarballs, then publishes the native packages before the launcher. Each
publication job uses the protected `npm`
environment and npm trusted publishing through GitHub OIDC. All three packages
have a trusted-publisher relationship for workflow `release.yml`, repository
`jderochervlk/rescript-lint`, environment `npm`, and publish permission. The
initial MFA bootstrap is complete; the release workflow has no registry token.
Each new version is published from verified workflow artifacts.

See [the release runbook](RELEASING.md) for the verified registry preflight,
approval gates, trusted-publisher verification, and partial-release recovery.

References: [npm package metadata](https://docs.npmjs.com/cli/v11/configuring-npm/package-json/),
[npm trusted publishing](https://docs.npmjs.com/trusted-publishers/),
[GitHub runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

## Deferred platforms

macOS and Windows are not in `npm/targets.json`, so CI and the launcher's
optional dependencies do not include them. Before reintroducing macOS, make the
CLI transcript and project tests portable to its Bash implementation, then pass
the full native packaging gates on Intel and Apple Silicon. Before reintroducing
Windows, resolve the fixture byte-comparison failures in `application_test`,
confirm checkout line endings without weakening CRLF preservation tests, and
audit DLL dependencies outside the Opam/Cygwin environment.
