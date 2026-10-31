# Public release audit and recovery

Created: 2026-10-31
Last updated: 2026-10-31
Status: Implemented (public metadata complete; consumer verification pending)
Issue: https://github.com/jderochervlk/rescript-lint/issues/30

## Purpose and usage

Run `npm run audit:release -- 0.1.0-alpha.3` to check an explicit public alpha
release independently of the local source version or configured npm proxy.
The command makes GET requests only to `https://registry.npmjs.org`, requires
the public launcher to reference all five supported native targets at the exact
release version, and queries each native version. Target names come from the
existing target catalog, not a second platform list.

It emits JSON and exits zero only for `PublicReleaseAvailable`. Missing versions
are reported separately from transport, HTTP, and malformed metadata errors.
Requests time out after 15 seconds each. No npm login or credentials are needed.
The command neither stages nor approves anything and is not an automated release
gate. It checks metadata availability, not tarball integrity, provenance, binary
correctness, or successful installation.

Follow [release recovery](../development/RELEASING.md#recovery) for human decisions
and npm 2FA actions. Existing stage-only OIDC permissions, alpha tags, compliance
checks, supported platforms, and native-before-launcher approvals are unchanged.
No source-only change can supply an absent public package version.

## Incident evidence

On 2026-10-31, public package metadata returned HTTP 200 for all six package
names. The launcher and Linux x64/ARM64 and Darwin x64/ARM64 packages contained
`0.1.0-alpha.3` with `alpha` pointing to it. Windows listed only `0.0.0-stage`
with `latest` pointing to that placeholder and no `alpha` tag. The public alpha.3
launcher referenced all five native alpha.3 versions.

The live audit returned `IncompleteRelease` with a single `MissingVersion`:
`@jvlk/rescript-lint-win32-x64@0.1.0-alpha.3` (exit 1). This is dated evidence,
not a permanent statement of registry state. Private pending stages were not
inspected by the agent.

Later on 2026-10-31, the maintainer reported approving and publishing the missing
Windows payload. The same live audit then returned `PublicReleaseAvailable`
(exit 0), confirming the launcher and all five exact native versions in public
npm. Publication was a maintainer action, not an effect of this tooling. The
original Yarn macOS ARM64 reproduction still needs consumer verification before
resolving the incident.

## Validation

Using Node 24.16.0 and npm 11.15.0:

- `node --test test/npm/public-release.test.mjs`: six tests passed.
- `npm run audit:release -- 0.1.0-alpha.3`: initially exit 1, missing Windows
  only; after maintainer publication, exit 0 with `PublicReleaseAvailable`.
- `node scripts/version/cli.mjs check`: passed, no version changes.
- `npm run prepare:licenses`, `npm test`, `npm run pack:native`,
  `npm run test:package`, `npm run test:rebuild`: passed. All 65 npm tests and
  packaging coverage gates passed at 100%; local Linux x64 smoke and source
  relinking checks passed, including the
  [dependency-pinning CI follow-up](verified-dependency-pins.md). No tarballs
  were uploaded by the agent.
- `DUNE_ROOT="$PWD" OPAMSWITCH=/home/josh/Dev/rescript-linter make check`:
  passed build, formatting, OCaml lint (488 sources, no findings), and tests.

Initial npm tests failed before the native binary was built and before the
compatible switch was selected. Plain `make check` followed an enclosing Dune
workspace; explicit `DUNE_ROOT` fixed that. Validation used the pinned ReScript
submodule initialized inside this worktree and an ignored local `_opam` symlink
to the existing switch (needed by a compliance test that sets `OPAMSWITCH` to
the worktree root). No toolchain installation or global configuration changed.

The issue's Yarn 4 macOS ARM64 reproduction was not run on this Linux host.
Other native binaries were not rebuilt here. No npm mutation, release tag,
workflow dispatch, or settings change was performed.

## Historical planning record

The following is the original plan committed before implementation, retained as
historical intent rather than an active checklist:

### Public release audit and recovery

Created: 2026-10-31
Last updated: 2026-10-31
Status: Planned
Issue: https://github.com/jderochervlk/rescript-lint/issues/30
Feature documentation: pending

#### Problem and intended outcome

The public alpha.3 launcher references a Windows version absent from npm.
Existing staging order and native-before-launcher approval instructions already
exist. Recovery currently lacks an explicit path for an already-public launcher.

#### Scope and non-goals

Add a read-only public release audit and an actionable recovery path. Do not
publish, stage, approve, change versions, drop targets, or alter release permissions.

#### Approach and decisions

Audit the explicitly selected public launcher manifest, not local source versions.
Resolve every exact optional dependency against public npm; fail closed on
registry errors. Keep the existing manual npm 2FA boundary.

#### Implementation steps

- Add an injectable registry audit and CLI with focused Node tests.
- Document recovery choices and remaining human actions.
- Preserve this plan in feature documentation on completion.

#### Validation

Run focused Node tests, npm test, the audit against alpha.3, version consistency,
and make check where feasible. An alpha.3 audit must fail naming Windows.

#### Open questions and remaining work

Private pending stages and reviewed artifacts require maintainer inspection.
Only a maintainer can choose completion of alpha.3 or a fresh corrected release.

### Dated decisions and completion

2026-10-31: Implemented the planned read-only audit and already-public-launcher
recovery path. No release version bump is justified without a maintainer decision
about retained original artifacts and private stages. Validation results above
describe delivered tooling, not resolution of the public release incident.
