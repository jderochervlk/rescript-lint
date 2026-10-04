# npm Release

The first published alpha was `0.1.0-alpha.1` on npm's `alpha` dist-tag. Each
alpha release contains the launcher plus Linux glibc and macOS native packages
on x64/ARM64, and Windows x64. Alpine/musl, Windows ARM64, and 32-bit systems
remain deferred.

## Before tagging

1. Update the version consistently in `dune-project`, `lib/cli/cli_command.ml`, and
   `npm/package.json`, then update the CLI transcript expectations. Confirm the
   planned version is not already published:

   ```sh
   version="$(node -p 'require("./npm/package.json").version')"
   npm whoami
   npm view "@jvlk/rescript-lint@$version" version
   npm view "@jvlk/rescript-lint-linux-x64-gnu@$version" version
   npm view "@jvlk/rescript-lint-linux-arm64-gnu@$version" version
   npm view "@jvlk/rescript-lint-darwin-x64@$version" version
   npm view "@jvlk/rescript-lint-darwin-arm64@$version" version
   npm view "@jvlk/rescript-lint-win32-x64@$version" version
   ```

   Each `npm view` command must report a 404 for the planned version.

2. Confirm `main` is pushed and all five native package jobs pass.
3. Confirm the protected GitHub `npm` environment requires the maintainer's
   approval. The release workflow requests only the `id-token: write` permission
   needed by npm; it stores no npm token.
4. Confirm the trusted publisher for each package (this may require npm MFA):

   ```sh
   npm trust list @jvlk/rescript-lint-linux-x64-gnu
   npm trust list @jvlk/rescript-lint-linux-arm64-gnu
   npm trust list @jvlk/rescript-lint-darwin-x64
   npm trust list @jvlk/rescript-lint-darwin-arm64
   npm trust list @jvlk/rescript-lint-win32-x64
   npm trust list @jvlk/rescript-lint
   ```

   Each result must name GitHub, `jderochervlk/rescript-lint`, `release.yml`,
   environment `npm`, and `publish` permission.

   If a new package does not exist yet, follow [Bootstrap new native packages](#bootstrap-new-native-packages)
   first. The workflow checks OIDC authentication for all six packages before
   publishing, but token exchange does not prove direct-publish permission.
   Manually verify `publish` permission for every publisher; a stage-only
   publisher can still cause a partial release.

## Bootstrap new native packages

Run these commands from the repository root in Bash or Zsh, with Node 24 or
newer, an authenticated GitHub CLI (`gh auth login`), and an npm maintainer
account with package write access and two-factor authentication. Trust setup
requires [npm 11.15.0 or newer](https://docs.npmjs.com/cli/v11/commands/npm-trust/).
Do not push a release tag during bootstrap.

### Build and download

Use a dedicated bootstrap version, such as `0.1.0-alpha.2`, aligned in the three
source files listed above. Push that commit, then build all five targets without
publishing. Use `main` after the PR is merged; before merging, use
`ci/shared-native-builds` as `build_ref`.

```sh
build_ref=main
gh workflow run release.yml --ref "$build_ref" -f publish=false
gh run list --workflow release.yml --branch "$build_ref"
```

Choose the run just dispatched, not an earlier run. Replace `YOUR_BUILD_RUN_ID`
below with its numeric ID. Confirm its `headSha` matches the intended pushed
commit and all five package jobs pass. Stop if the run fails.

```sh
RUN_ID=YOUR_BUILD_RUN_ID
gh run view "$RUN_ID" --json headSha,headBranch,conclusion,url
gh run watch "$RUN_ID" --exit-status
```

Download to a fresh, run-specific directory. Keep this shell open for the
remaining commands. Artifacts expire after 30 days; rebuild if unavailable.

```sh
artifact_dir="bootstrap-artifacts/$RUN_ID"
gh run download "$RUN_ID" --pattern 'packages-*' --dir "$artifact_dir"
version=0.1.0-alpha.2
```

Set `version` to the version embedded in that run's tarballs, not a newer local
checkout. Inspect all three new native packages before publishing:

```sh
(
  set -e
  for target in darwin-x64 darwin-arm64 win32-x64; do
    npm publish \
      "./$artifact_dir/packages-$target/jvlk-rescript-lint-$target-$version.tgz" \
      --dry-run --access public --tag bootstrap
  done
)
```

Check the package names, versions, native executable, license, and corresponding
source bundle in the output. A dry run does not verify registry permissions.

### Publish and configure trust

Log in interactively as the maintainer. Do not store credentials in the repo.

```sh
npm install --global npm@11.15.0
npm login
npm whoami
```

Before starting, verify each `npm view` reports a 404 for this version. An
authentication or network error is not confirmation that a version is absent.

```sh
for target in darwin-x64 darwin-arm64 win32-x64; do
  npm view "@jvlk/rescript-lint-$target@$version" version
done
```

Publish only the three new native packages, then configure their trusted
publishers. Complete npm's MFA prompts. The `bootstrap` tag keeps these versions
off the `alpha` and `latest` tags; do not publish the Linux packages or launcher
during this step.

```sh
(
  set -e
  for target in darwin-x64 darwin-arm64 win32-x64; do
    npm publish \
      "./$artifact_dir/packages-$target/jvlk-rescript-lint-$target-$version.tgz" \
      --access public --tag bootstrap
    npm trust github "@jvlk/rescript-lint-$target" \
      --repo jderochervlk/rescript-lint --file release.yml \
      --environment npm --allow-publish
  done
)
```

The loop stops at the first failure. If publication succeeds but trust setup
fails, retry only `npm trust github` for that package; never republish an existing
version. Inspect `npm view` and `npm trust list` before resuming, and run the two
commands separately for each remaining unpublished target. If a trust entry
already exists, verify it rather than blindly creating a duplicate.

### First full release

Do not tag the bootstrap version: only three of the six packages exist at that
version, so the partial-release guard will refuse it. Bump the aligned source
version to a fresh value, such as `0.1.0-alpha.3`, commit and merge it, then repeat
[Before tagging](#before-tagging), including all six trust checks. Explicit
`--allow-publish` is required for this direct-publishing workflow; stage-publish
permission alone is insufficient.

## Automated release

After merging the release candidate to `main`, create and push the matching tag:

```sh
git switch main
git pull --ff-only origin main
version="$(node -p 'require("./npm/package.json").version')"
git tag -a "v$version" -m "v$version"
git push origin "v$version"
```

The tag starts `.github/workflows/release.yml`. It rebuilds all native
targets, performs source-bundle and installed-package checks, publishes the five
native packages, verifies their registry versions, then publishes and smoke-tests
the launcher. Approve its `npm` environment prompts after inspecting the run.

If a native publication fails, do not publish the launcher. Published npm
versions cannot be replaced; change the version in the source, rebuild all six
packages, and release a new tag instead of reusing a version. If some but not all
packages are published, stop: the workflow detects this partial-release state and
will not continue automatically.
