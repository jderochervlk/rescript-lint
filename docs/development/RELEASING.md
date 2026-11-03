# npm Release

Automatic alpha staging is implemented locally but remains operationally
disabled until maintainers review the cutoff, create the protected data-only
ledger branch, verify every npm trusted publisher, and authorize environment
changes. Do not set `ALPHA_STAGING_AUTOMATION_ENABLED` or initialize remote state
as part of normal release work. See the
[automatic staging feature contract](../features/automatic-alpha-staging.md).

The operator-only ledger commands require repository write access through an
authenticated `gh` session. Set these process environment variables in the
operator shell (do not enable shell tracing):

```sh
export GITHUB_REPOSITORY=jderochervlk/rescript-lint
export GH_TOKEN="$(gh auth token)"
npm run ledger:alpha-staging -- inspect
npm run ledger:alpha-staging -- bootstrap --confirm-bootstrap --cutoff=22
```

Bootstrap is a one-time remote write and is not part of Actions. Run it only
after the reviewed cutoff and ledger-branch protection are approved. Never use
bootstrap to reset or recreate existing state.

Each release contains the launcher plus Linux glibc and macOS native packages
on x64/ARM64, and Windows x64. CI builds and stages all six packages on npm's
`alpha` dist-tag. A maintainer reviews and approves each staged package with
npm two-factor authentication (2FA); CI never approves or directly publishes a
release. Alpine/musl, Windows ARM64, and 32-bit systems remain deferred.

Staging requires Node 24+ and [npm 11.15.0 or newer](https://docs.npmjs.com/staged-publishing/).
Approvals require an npm maintainer account with package write access and 2FA.
GitHub environment approval permits staging; it is not npm publication approval.

## Before tagging

1. Use the [alpha version updater and reconciliation protocol](../features/alpha-version-automation.md),
   not independent multi-file edits. The built-in `GITHUB_TOKEN`
   [workflow](../../.github/workflows/alpha-versions.yml) requires
   [repository PR permission and explicit opt-in](../features/alpha-version-automation.md#one-time-repository-setup-and-opt-in),
   not a custom App or new secrets. Its PR CI can require maintainer approval.
   Until it is configured and enabled, use
   `node scripts/version/cli.mjs dry-run COUNT` and `update COUNT` in a reviewed
   PR, where COUNT is the number of new source merges. The updater owns the
   manifest, Dune, CLI, generated Opam metadata and CLI/LSP expectations.
   Keep manual updates separate from the automation checkpoint unless performing
   an explicitly reviewed migration. Run `node scripts/version/cli.mjs check`.
   Confirm the planned version is neither published nor already staged:

   ```sh
   version="$(node -p 'require("./npm/package.json").version')"
   npm login
   npm whoami
   for package in \
     @jvlk/rescript-lint-linux-x64-gnu \
     @jvlk/rescript-lint-linux-arm64-gnu \
     @jvlk/rescript-lint-darwin-x64 \
     @jvlk/rescript-lint-darwin-arm64 \
     @jvlk/rescript-lint-win32-x64 \
     @jvlk/rescript-lint; do
     npm view "$package@$version" version
     npm stage list "$package" --json
   done
   ```

   Each `npm view` must report a 404 for the planned version, and no stage list
   may contain that version. Authentication or network errors are not evidence
   of absence. Staged and published versions share the same uniqueness constraint.

2. Confirm `main` is pushed and all five native package jobs pass.
3. Confirm the protected GitHub `npm` environment requires maintainer approval.
   CI uses GitHub OIDC with `id-token: write`; it stores no npm token or OTP.
4. Verify each package's trusted publisher:

   ```sh
   for package in \
     @jvlk/rescript-lint-linux-x64-gnu \
     @jvlk/rescript-lint-linux-arm64-gnu \
     @jvlk/rescript-lint-darwin-x64 \
     @jvlk/rescript-lint-darwin-arm64 \
     @jvlk/rescript-lint-win32-x64 \
     @jvlk/rescript-lint; do
     npm trust list "$package"
   done
   ```

   Each publisher must identify GitHub, `jderochervlk/rescript-lint`, workflow
   `release.yml`, environment `npm`, and stage-publish permission. Prefer
   stage-only permissions and package access set to "Require two-factor
   authentication and disallow tokens". Older direct-publish-only connections
   must be replaced with a stage-enabled connection before releasing.

   The OIDC preflight checks authentication, not allowed actions; actual staging
   enforces stage permission. A failed upload can leave pending stages, but no
   release version is approved automatically. See [Recovery](#recovery).

## Bootstrap new native packages

If a package name does not exist yet, stage it locally with your maintainer
login to create it, then configure its trusted publisher. npm creates a public
`0.0.0-stage` placeholder for a new name; the staged release payload remains
private until approval. Do not approve bootstrap stages or push a release tag
during bootstrap.

### Build and download

Use a dedicated bootstrap version, such as `0.1.0-alpha.2`, aligned in the three
source files above. Build all five targets without uploading to npm. Use `main`
after this PR is merged; before merging, use `ci/shared-native-builds`.

```sh
build_ref=main
gh workflow run release.yml --ref "$build_ref" -f stage=false
gh run list --workflow release.yml --branch "$build_ref"
```

Choose the exact run just dispatched. Confirm its `headSha` matches the intended
pushed commit and all five package jobs pass. Stop on failure.

```sh
RUN_ID=YOUR_BUILD_RUN_ID
gh run view "$RUN_ID" --json headSha,headBranch,conclusion,url
gh run watch "$RUN_ID" --exit-status
artifact_dir="bootstrap-artifacts/$RUN_ID"
gh run download "$RUN_ID" --pattern 'packages-*' --dir "$artifact_dir"
version=0.1.0-alpha.2
```

Use the version embedded in that run's tarballs, not a newer local checkout.
Inspect all three new native packages before staging:

```sh
(
  set -e
  for target in darwin-x64 darwin-arm64 win32-x64; do
    npm stage publish \
      "./$artifact_dir/packages-$target/jvlk-rescript-lint-$target-$version.tgz" \
      --dry-run --access public --tag bootstrap --ignore-scripts
  done
)
```

Check names, versions, executable, licenses, and corresponding source bundle.
A dry run does not verify registry permissions. Artifacts expire after 30 days.

### Stage and configure trust

```sh
npm install --global npm@11.15.0
npm login
npm whoami
```

Check `npm view` and `npm stage list` for each name/version first. Run only for
the missing packages; do not recreate existing publishers blindly.

```sh
(
  set -e
  for target in darwin-x64 darwin-arm64 win32-x64; do
    npm stage publish \
      "./$artifact_dir/packages-$target/jvlk-rescript-lint-$target-$version.tgz" \
      --access public --tag bootstrap --ignore-scripts
    npm trust github "@jvlk/rescript-lint-$target" \
      --repo jderochervlk/rescript-lint --file release.yml \
      --environment npm --allow-stage-publish
  done
)
```

Record the stage IDs. If trust setup fails after staging, retry only trust setup,
not the upload. Inspect existing connections with `npm trust list`. To replace
an old direct-publish-only connection, revoke its confirmed ID with
`npm trust revoke PACKAGE --id=TRUST_ID`, then recreate it with
`--allow-stage-publish`; complete the MFA prompts.

Review each bootstrap stage with `npm stage view STAGE_ID` and remove it with
`npm stage reject STAGE_ID` (2FA). Do not approve these bootstrap-only versions.
For the first full release, use a fresh aligned version such as
`0.1.0-alpha.3`, and repeat all six checks in [Before tagging](#before-tagging).

## Stage a release

After a registered version PR merges to `main`, `release.yml` selects the oldest
eligible unreconciled merge on the main-push fast path or the scheduled,
approximately 15-minute sweep throughout the day. GitHub may suppress
bot-originated push events; the sweep recovers those merges and coalesced
wakeups. The default
opt-in remains disabled. The state ledger must already exist with the reviewed
cutoff; automation fails closed if it is absent, corrupt, or unfinished. See the
[automatic staging contract](../features/automatic-alpha-staging.md) and
[implementation/rollout plan](../plans/automatic-alpha-staging.md).

Until the separate rollout is approved, do not set
`ALPHA_STAGING_AUTOMATION_ENABLED`, initialize the remote ledger, or remove the
GitHub `npm` environment reviewer. The present environment still requires
maintainer approval before staging. Before ever removing that gate, restrict
environment deployments to `main` and matching release tags, verify all six
npm trusted publishers are stage-only, and confirm npm publication still
requires maintainer 2FA. The environment currently has no deployment-branch
policy; do not change settings as part of ordinary releases.

The explicit staging workflow dispatch is only from `main`; it selects the
oldest pending registered release and uses the same ledger protocol. A manual
dispatch with `stage=false` remains build-only and may use a diagnostic ref.
Matching `v0.1.0-alpha.N` tags resolve to their canonical registered version
merge SHA; a completed tag request is a zero-upload no-op. Tags cannot select a
different source or bypass an earlier unfinished attempt.

All staging paths use one concurrency group, rebuild the immutable selected
source, and download only artifacts from that same workflow run. Target evidence
binds source SHA, expected version, run ID, native target, exact package set,
archive manifests, and each tarball digest. The staging job validates all six
artifacts before OIDC authentication, writes and rereads its ledger attempt
before the first upload, and stages five native packages before the launcher.
The ledger records accepted stage IDs and only becomes `Staged` after all six
uploads are confirmed. An already completed version is a no-op.

If a staging attempt is partial, canceled, or has an unknown response, do not
rerun or locally substitute a rebuilt tarball. The ledger blocks automatic
retries and requires inspection of every npm stage using a maintainer login.
Recovery must use the original verified artifacts and an explicit maintainer
decision; never force-update/reset the ledger. A green staging run means stages
await npm review, not public release.

## Review and approve with 2FA

Wait for all six uploads to succeed before approving anything. Log in as the
maintainer and list each package's stages:

```sh
npm login
npm stage list @jvlk/rescript-lint-darwin-arm64 --json
npm stage view STAGE_ID --json
npm stage download STAGE_ID
```

Repeat for all five native packages and the launcher. Verify the package name,
version, `alpha` tag, provenance where available, and downloaded tarball against
the verified build artifact. The staging tag is immutable; reject and re-stage
if it is wrong. Keep the six reviewed stage IDs associated with the exact run.

Approve each native stage first, completing npm's 2FA prompts:

```sh
npm stage approve LINUX_X64_STAGE_ID
npm stage approve LINUX_ARM64_STAGE_ID
npm stage approve DARWIN_X64_STAGE_ID
npm stage approve DARWIN_ARM64_STAGE_ID
npm stage approve WINDOWS_X64_STAGE_ID
```

Confirm all five native versions are publicly available before approving the
launcher. Set `version` to the reviewed release version:

```sh
(
set -e
for target in linux-x64-gnu linux-arm64-gnu darwin-x64 darwin-arm64 win32-x64; do
  published="$(npm view "@jvlk/rescript-lint-$target@$version" version)"
  test "$published" = "$version"
done
npm stage approve LAUNCHER_STAGE_ID
npm exec --yes --package "@jvlk/rescript-lint@$version" -- rescript-lint --version
)
```

Do not approve the launcher if any native lookup fails or reports another
version. You may also review and approve through npmjs.com's Staged Packages
tab; npm still requires 2FA. Approval is per package, not atomic across six
packages. Never store OTPs or login credentials in this repository or CI.

## Recovery

### Launcher already public with a missing native version

For an availability report such as [#30](https://github.com/jderochervlk/rescript-lint/issues/30),
audit the **published** launcher and every referenced native version:

```sh
npm run audit:release -- 0.1.0-alpha.3
```

This read-only command always queries public npm, not your configured proxy or
local source version. It exits nonzero for missing versions, unexpected launcher
dependencies, malformed metadata, or registry/network errors. A `MissingVersion`
is different from a `RegistryError`; do not infer absence from a failed request.
It checks metadata availability, not tarball contents or installation.
See [the audit contract](../features/public-release-audit.md).

A `0.0.0-stage` placeholder does **not** satisfy an exact native dependency.
Yarn can require resolution of every optional dependency even on another OS.
Changing a dist-tag, dropping Windows from source, or merging this repository
cannot repair the already-published launcher's dependency graph.

A maintainer with npm access must choose one of these recovery paths:

1. **Complete the existing version**, only if the missing native's exact original
   verified release artifact can be established. Inspect `npm stage list PACKAGE
   --json` and `npm stage view STAGE_ID --json` with the maintainer login.
   A public lookup cannot tell whether a private stage exists. Review the stage
   and downloaded tarball against that release's verified build as described in
   [Review and approve with 2FA](#review-and-approve-with-2fa), then approve only
   the missing reviewed native stage with 2FA. If no stage exists but the exact
   verified original tarball is retained, follow the missing-upload recovery below,
   then review and approve it. Do not rerun uploads for already-public packages.
2. **Supersede with a fresh aligned alpha**, if the original artifact cannot be
   established or is wrong. Use the existing version updater in a reviewed PR,
   then follow the normal six-package build, staging and manual approval flow.
   Do not silently substitute a new build under the old release version.
   A fresh release does not repair installs explicitly pinned to alpha.3;
   tell affected users which complete version to select.

After maintainer action, rerun the audit for the intended consumer version and
the issue's public-registry Yarn reproduction on a supported host. Record those
results in the incident before marking it resolved. A green source PR or staging
workflow alone is not public remediation. Never unpublish, retag, or deprecate a
release as an implicit recovery step.

### Partial staging or approval

- If staging fails partway, approve nothing. The persistent ledger is marked
  `NeedsInspection` (or remains ambiguous if its write response was lost) and
  prevents another automatic attempt. Use `npm stage list` and `npm stage view`
  with maintainer credentials to inspect all six package outcomes. Do not rerun
  the job or locally upload a partial subset as a retry. Recovery requires
  maintainer inspection of the original run, ledger tip, exact accepted stage
  IDs, and original verified artifacts; record the approved recovery decision
  separately. If exact original artifacts are unavailable, use a fresh version.
- If approval fails after some native packages are public, leave the launcher
  pending and resume approval of the remaining reviewed native stages. Do not
  re-stage already published versions or rerun the CI upload job.
- If a public package is wrong, its version cannot be replaced. Stop, reject
  remaining pending stages, bump all aligned versions, rebuild, and release a
  fresh version. Staging prevents CI from publishing a partial release, but
  manual approvals can still produce a partial public release.

References: [npm staged publishing](https://docs.npmjs.com/staged-publishing/),
[stage commands](https://docs.npmjs.com/cli/v11/commands/npm-stage/),
[trusted publisher permissions](https://docs.npmjs.com/trusted-publishers/).
