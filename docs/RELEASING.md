# npm Release

The first published alpha was `0.1.0-alpha.1` on npm's `alpha` dist-tag. Each
alpha release contains the launcher plus two Linux glibc native packages: x64
and ARM64. macOS, Windows, Alpine/musl, and 32-bit systems remain deferred.

## Before tagging

1. Update the version consistently in `dune-project`, `lib/command.ml`, and
   `npm/package.json`, then update the CLI transcript expectations. Confirm the
   planned version is not already published:

   ```sh
   version="$(node -p 'require("./npm/package.json").version')"
   npm whoami
   npm view "@jvlk/rescript-lint@$version" version
   npm view "@jvlk/rescript-lint-linux-x64-gnu@$version" version
   npm view "@jvlk/rescript-lint-linux-arm64-gnu@$version" version
   ```

   Each `npm view` command must report a 404 for the planned version.

2. Confirm `main` is pushed and its CI and two Linux npm package jobs pass.
3. Confirm the protected GitHub `npm` environment requires the maintainer's
   approval. The release workflow requests only the `id-token: write` permission
   needed by npm; it stores no npm token.
4. Confirm the trusted publisher for each package (this may require npm MFA):

   ```sh
   npm trust list @jvlk/rescript-lint-linux-x64-gnu
   npm trust list @jvlk/rescript-lint-linux-arm64-gnu
   npm trust list @jvlk/rescript-lint
   ```

   Each result must name GitHub, `jderochervlk/rescript-lint`, `release.yml`,
   environment `npm`, and `publish` permission.

## Automated release

After merging the release candidate to `main`, create and push the matching tag:

```sh
git switch main
git pull --ff-only origin main
version="$(node -p 'require("./npm/package.json").version')"
git tag -a "v$version" -m "v$version"
git push origin "v$version"
```

The tag starts `.github/workflows/release.yml`. It rebuilds and tests both Linux
targets, performs source-bundle and installed-package checks, publishes the two
native packages, verifies their registry versions, then publishes and smoke-tests
the launcher. Approve its `npm` environment prompts after inspecting the run.

If a native publication fails, do not publish the launcher. Published npm
versions cannot be replaced; change the version in the source, rebuild all three
packages, and release a new tag instead of reusing a version. If some but not all
packages are published, stop: the workflow detects this partial-release state and
will not continue automatically.
