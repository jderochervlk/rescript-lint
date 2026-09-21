# First npm Release

The first release is `0.1.0-alpha.1` on npm's `alpha` dist-tag. It contains the
launcher plus two Linux glibc native packages: x64 and ARM64. macOS, Windows,
Alpine/musl, and 32-bit systems are deferred.

## Before tagging

1. Confirm `main` is pushed and its CI and two Linux npm package jobs pass.
2. Recheck availability immediately before release:

   ```sh
   npm whoami
   npm org ls jvlk --json
   npm view @jvlk/rescript-lint version
   npm view @jvlk/rescript-lint-linux-x64-gnu version
   npm view @jvlk/rescript-lint-linux-arm64-gnu version
   ```

   The three `npm view` commands must report a 404 for this first version.

3. Configure npm trusted publishing for each package with GitHub owner
   `jderochervlk`, repository `rescript-lint`, workflow `release.yml`, and
   environment `npm`. Create a protected GitHub environment named `npm` and make
   the maintainer its required reviewer. The release workflow requests only the
   `id-token: write` permission needed by npm; it stores no npm token.

4. npm may require the first public version of a new package to be published
   interactively before it accepts a trusted publisher. Use the MFA-authenticated
   bootstrap commands below if required, then configure the trusted publisher in
   npm before tagging the next version. Do not commit an npm token or OTP.

## Bootstrap publication

Build the exact source that will be released on each Linux target, then publish
the two native tarballs before the launcher. These commands are for the
maintainer's interactive, MFA-authenticated session:

```sh
gh workflow run release.yml --ref main -f publish=false
release_run="$(gh run list --workflow release.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')"
gh run watch "$release_run" --exit-status
gh run download "$release_run" --name packages-linux-x64-gnu --dir release-artifacts/linux-x64-gnu
gh run download "$release_run" --name packages-linux-arm64-gnu --dir release-artifacts/linux-arm64-gnu
npm login
npm publish --access public --tag alpha release-artifacts/linux-x64-gnu/jvlk-rescript-lint-linux-x64-gnu-0.1.0-alpha.1.tgz
npm publish --access public --tag alpha release-artifacts/linux-arm64-gnu/jvlk-rescript-lint-linux-arm64-gnu-0.1.0-alpha.1.tgz
npm publish --access public --tag alpha release-artifacts/linux-x64-gnu/jvlk-rescript-lint-0.1.0-alpha.1.tgz
```

Use tarballs produced by the Ubuntu 22.04 GitHub runners, not a locally-built
binary. The build-only workflow run retains each target's tarballs as artifacts.
Publish the launcher tarball from `packages-linux-x64-gnu` after both native
packages are available.

Verify each package before continuing:

```sh
npm view @jvlk/rescript-lint-linux-x64-gnu@0.1.0-alpha.1 version
npm view @jvlk/rescript-lint-linux-arm64-gnu@0.1.0-alpha.1 version
npm view @jvlk/rescript-lint@0.1.0-alpha.1 version
npm exec --yes --package @jvlk/rescript-lint@0.1.0-alpha.1 -- rescript-lint --version
```

## Automated release

Once npm trusted publishing accepts all three packages, create and push the tag:

```sh
git switch main
git pull --ff-only origin main
git tag -a v0.1.0-alpha.1 -m "v0.1.0-alpha.1"
git push origin v0.1.0-alpha.1
```

The tag starts `.github/workflows/release.yml`. It rebuilds and tests both Linux
targets, performs source-bundle and installed-package checks, publishes the two
native packages, verifies their registry versions, then publishes and smoke-tests
the launcher. Approve its `npm` environment prompts after inspecting the run.

If a native publication fails, do not publish the launcher. Published npm
versions cannot be replaced; change the version in the source, rebuild all three
packages, and release a new tag instead of reusing a version.
