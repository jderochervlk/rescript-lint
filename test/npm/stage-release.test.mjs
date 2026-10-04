import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import targets from "../../npm/targets.json" with { type: "json" };
import manifest from "../../npm/package.json" with { type: "json" };
import { packageName } from "../../npm/lib/platform.mjs";
import { releasePackages, stageRelease } from "../../scripts/npm/stage-release.mjs";

const packages = releasePackages({ targets, manifest, artifacts: "/artifacts" });
const env = { ACTIONS_ID_TOKEN_REQUEST_URL: "https://oidc.example/token",
  ACTIONS_ID_TOKEN_REQUEST_TOKEN: "fixture-secret" };
const request = async url => ({ ok: true, json: async () => String(url).includes("oidc.example")
  ? { value: "fixture-oidc" } : { token: "fixture-token" } });
const unexpected = () => assert.fail("Unexpected side effect");

test("plans all five native tarballs and one launcher in dependency order", () => {
  assert.deepEqual(packages.map(entry => entry.name), [...targets.map(packageName), manifest.name]);
  for (const [index, target] of targets.entries()) {
    assert.equal(packages[index].tarball, join("/artifacts", `packages-${target.id}`,
      `jvlk-rescript-lint-${target.id}-${manifest.version}.tgz`));
  }
  assert.equal(packages.at(-1).tarball, join("/artifacts", `packages-${targets[0].id}`,
    `jvlk-rescript-lint-${manifest.version}.tgz`));
  assert.deepEqual(releasePackages({ targets: [], manifest, artifacts: "/artifacts" }), []);
});

test("checks every artifact and publisher before staging anything", async () => {
  const events = [];
  const checked = await stageRelease({ packages, env,
    exists: path => { events.push(["artifact", path]); return true; },
    request: async url => { events.push(["auth", String(url)]); return request(url); },
    stage: entry => { events.push(["stage", entry.name]); return { _tag: "PackageStaged" }; },
  });
  assert.deepEqual(checked, { _tag: "ReleaseStaged", packages: packages.map(entry => entry.name) });
  assert.deepEqual(events.slice(0, 6), packages.map(entry => ["artifact", entry.tarball]));
  assert.equal(events.slice(6, 13).every(([action]) => action === "auth"), true);
  assert.deepEqual(events.slice(13), packages.map(entry => ["stage", entry.name]));
});

test("invalid plans and missing artifacts fail before authentication or uploads", async () => {
  const base = { env, request: unexpected, stage: unexpected };
  assert.equal((await stageRelease({ ...base, packages: [], exists: unexpected }))._tag, "ReleaseInvalid");
  const checked = await stageRelease({ ...base, packages, exists: path => path !== packages.at(-1).tarball });
  assert.equal(checked._tag, "ArtifactMissing");
  assert.match(checked.message, /Missing verified tarball for @jvlk\/rescript-lint:/);
});

test("an unconfigured publisher prevents all staging", async () => {
  const checked = await stageRelease({ packages, env, exists: () => true, stage: unexpected,
    request: async url => String(url).includes("darwin-x64")
      ? { ok: false, status: 404 } : request(url),
  });
  assert.equal(checked._tag, "PublisherUnavailable");
  assert.match(checked.message, /darwin-x64.*HTTP 404/);
});

test("failed uploads stop later packages and retain the staged prefix for recovery", async () => {
  const uploaded = [];
  const checked = await stageRelease({ packages, env, request, exists: () => true,
    stage: entry => {
      uploaded.push(entry.name);
      return entry.name === packages[2].name
        ? { _tag: "StagingFailed", message: "Stage-only upload rejected." }
        : { _tag: "PackageStaged" };
    },
  });
  assert.deepEqual(uploaded, packages.slice(0, 3).map(entry => entry.name));
  assert.deepEqual(checked, { _tag: "StagingFailed", message: "Stage-only upload rejected.",
    staged: packages.slice(0, 2).map(entry => entry.name) });
});

test("filesystem and command exceptions become errors without exposing credentials", async () => {
  for (const boundary of ["exists", "stage"]) {
    const fail = () => { throw new Error("fixture-secret"); };
    const checked = await stageRelease({ packages, env, request, exists: () => true,
      stage: () => ({ _tag: "PackageStaged" }), [boundary]: fail });
    assert.equal(checked._tag, "StagingFailed");
    assert.doesNotMatch(checked.message, /fixture-secret/);
    assert.match(checked.message, /Inspect npm stage list/);
  }
});

test("CLI only stages tarballs and leaves 2FA approval to the maintainer", () => {
  const script = fileURLToPath(new URL("../../scripts/npm/stage-release-cli.mjs", import.meta.url));
  const setup = status => `
    import fs from "node:fs";
    import child from "node:child_process";
    import { syncBuiltinESMExports } from "node:module";
    fs.existsSync = () => true;
    globalThis.fetch = async url => ({ok: true, json: async () => String(url).includes("oidc.example")
      ? {value: "fixture-token"} : {token: "fixture-token"}});
    child.spawnSync = (command, args, options) => {
      console.log(JSON.stringify({command, args, options}));
      return {status: ${status}};
    };
    syncBuiltinESMExports();`;
  const run = (status, npmPath) => spawnSync(process.execPath,
    ["--import", `data:text/javascript,${encodeURIComponent(setup(status))}`, script],
    { encoding: "utf8", env: { ...process.env, ...env, npm_execpath: npmPath } });
  const ready = run("0", "fixture-npm-cli.js");
  assert.equal(ready.status, 0, ready.stderr);
  const commands = ready.stdout.trim().split("\n").slice(0, -1).map(line => JSON.parse(line));
  assert.equal(commands.length, 6);
  for (const [index, command] of commands.entries()) {
    assert.equal(command.command, process.execPath);
    assert.deepEqual(command.args.slice(0, 3), ["fixture-npm-cli.js", "stage", "publish"]);
    assert.equal(command.args[3].endsWith(packages[index].tarball.slice("/artifacts/".length)), true);
    assert.deepEqual(command.args.slice(4), ["--access", "public", "--tag", "alpha", "--ignore-scripts"]);
    assert.deepEqual(command.options, { stdio: "inherit", timeout: 120_000 });
  }
  assert.match(ready.stdout, /approve native packages before the launcher with npm 2FA/);
  for (const status of ["1", "null"]) {
    const failed = run(status, "fixture-npm-cli.js");
    assert.equal(failed.status, 2);
    assert.match(failed.stderr, /Staging failed for.*linux-x64-gnu/);
    assert.equal(failed.stdout.trim().split("\n").length, 1);
  }
  const missingNpm = run("0", "");
  assert.equal(missingNpm.status, 2);
  assert.match(missingNpm.stderr, /Run npm run stage:release/);
  assert.equal(missingNpm.stdout, "");
});

test("workflow requires staged publishing support and never approves or installs releases", () => {
  const workflow = readFileSync(new URL("../../.github/workflows/release.yml", import.meta.url), "utf8");
  assert.match(workflow, /npm@11\.15\.0/);
  assert.match(workflow, /inputs\.stage/);
  assert.match(workflow, /run: npm run stage:release/);
  assert.doesNotMatch(workflow, /npm publish|npm stage approve|npm exec|inputs\.publish/);
});
