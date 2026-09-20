# First npm Release

This is a preparation runbook, not permission to publish. Publication guards
remain enabled until the checks below are complete and the maintainer approves
the release.

## Registry preflight

Verified on 2026-09-20 against `https://registry.npmjs.org`:

- `npm whoami` returned `jderochervlk`.
- `npm org ls jvlk --json` reported that account as an organization owner.
- Public metadata requests returned HTTP 404 for all six intended names:
  `@jvlk/rescript-lint`, `@jvlk/rescript-lint-linux-x64-gnu`,
  `@jvlk/rescript-lint-linux-arm64-gnu`, `@jvlk/rescript-lint-darwin-x64`,
  `@jvlk/rescript-lint-darwin-arm64`, and `@jvlk/rescript-lint-win32-x64`.

These checks do not reserve names or prove that a publish will succeed. Recheck
immediately before release. Do not paste credentials or OTPs into issue reports,
commit them, or add a long-lived write token to the repository.

## Release gates

1. Complete the [distribution review](DISTRIBUTION.md), including a per-target
   dependency inventory, applicable license texts/notices, and required source
   distribution. Add package-content tests for the resulting license bundle.
2. Require successful OCaml CI and all five native package jobs for the exact
   release commit. Inspect dynamic dependencies and document minimum OS support.
   Test Windows without the Opam/Cygwin runtime available. Do not use this
   development machine's Linux binary as the Ubuntu 22.04 release build.
3. Confirm the version and dist-tag. Recommended first release:
   `0.1.0-beta.1` with `beta`, pending maintainer approval. Keep `dune-project`,
   `lib/command.ml`, and `npm/package.json` synchronized. Update version-specific
   assertions in the tests; retain the binary/manifest equality check.
4. Replace preparation-only wording in `npm/README.md` and distribution docs
   with verified release facts. Keep the limited throws and hooks guarantees.
5. Remove `private: true` from the launcher template and native manifest
   generator only after the previous gates pass. Update the corresponding tests
   to assert the intended public metadata, not bypass metadata verification.
   The repository tooling package stays private.
6. Add a protected release workflow before creating a version tag. Build all
   targets from that tag, retain checksums and source provenance, and aggregate
   only that run's artifacts. Verify all native packages use the exact launcher
   version and that every runner produced the same launcher contents.
7. Run `npm publish --dry-run --access public --tag beta <tarball>` for all six
   final tarballs. A dry run is not a registry permission or name-ownership test.

## Publishing setup

Use npm trusted publishing with a dedicated workflow, planned as
`.github/workflows/release.yml`, and a protected `npm` GitHub environment.
Configure each package for GitHub owner `jderochervlk`, repository `rescript-lint`,
workflow `release.yml`, and environment `npm`. That workflow does not exist yet;
do not configure a different filename by accident.

The publish job needs `id-token: write` and `contents: read`, GitHub-hosted
runners, Node 24, and npm >=11.5.1. Keep PR jobs credential-free. npm now supports
stage-only trusted publishers, allowing maintainer review and 2FA approval
before a package becomes public. Prefer that approval path; direct `npm publish`
must be explicitly allowed if selected instead. See
[npm's trusted-publishing setup](https://docs.npmjs.com/trusted-publishers/).

Package settings may require an initial authenticated bootstrap publication.
Verify the registry setup for these new names before depending on OIDC; local
`npm whoami` is not an OIDC test. Keep any interactive bootstrap separate from
automated publication and require explicit maintainer approval.

## Publication order and recovery

1. Publish or approve the five native packages at the same exact version first.
   Verify each version and integrity against the approved tarball in the registry.
2. Publish or approve the launcher last, with exact-version optional dependencies
   pointing to those five packages. Do not move `latest` for a beta release.
3. On every target, install the launcher alone from the registry into a clean
   project, with an empty npm cache. Verify optional dependency selection, help,
   version, findings, errors, and `--fix`. Local offline tests install the native
   tarball explicitly, so they do not establish registry resolution behavior.
4. Record the tag, source commit, CI run, checksums, target environments, and
   registry smoke-test results with the release.

If a native publication fails, stop before publishing the launcher. For a partial
release, compare already-published package integrity before resuming. Never
overwrite or silently reuse a version with different contents. If contents must
change, choose a new version for all six packages and rebuild. Avoid unpublishing
as an automatic recovery step.
