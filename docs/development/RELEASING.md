# npm Release

Each release contains the launcher plus Linux glibc and macOS native packages
on x64/ARM64, and Windows x64. CI builds and stages all six packages on npm's
`alpha` dist-tag. A maintainer reviews and approves each staged package with
npm two-factor authentication (2FA); CI never approves or directly publishes a
release. Alpine/musl, Windows ARM64, and 32-bit systems remain deferred.

Staging requires Node 24+ and [npm 11.15.0 or newer](https://docs.npmjs.com/staged-publishing/).
Approvals require an npm maintainer account with package write access and 2FA.
GitHub environment approval permits staging; it is not npm publication approval.

## Before tagging

1. Update the version consistently in `dune-project`, `lib/cli/cli_command.ml`, and
   `npm/package.json`, then update the CLI transcript expectations. Confirm the
   planned version is neither published nor already staged:

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

After merging the release candidate to `main`, create and push the matching tag:

```sh
git switch main
git pull --ff-only origin main
version="$(node -p 'require("./npm/package.json").version')"
git tag -a "v$version" -m "v$version"
git push origin "v$version"
```

The tag rebuilds and verifies all five targets, archives their tarballs, and
stages the five native packages followed by the launcher using `--tag alpha`.
Approve the GitHub `npm` environment after inspecting the build. The staging
job's npm output includes stage IDs. A green workflow means staging completed,
not that the release is publicly available.

Alternatively, dispatch the same flow from a chosen pushed ref:

```sh
gh workflow run release.yml --ref main -f stage=true
```

`stage=false` is the default for build-only dispatches. The previous `publish`
input no longer exists. Do not rerun staging blindly: an existing staged or
published version cannot be uploaded again. The CI OIDC token cannot list,
approve, or reject stages; recovery uses your maintainer login.

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

- If staging fails partway, approve nothing. Use `npm stage list` and `view` to
  identify every pending upload, including one accepted before a network error.
  Fix the permission or network issue, then stage only the missing verified
  tarballs locally with `npm stage publish TARBALL --access public --tag alpha
  --ignore-scripts`. Alternatively, reject all pending stages with 2FA before
  rerunning the staging job. Never replace reviewed artifacts with another build.
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
