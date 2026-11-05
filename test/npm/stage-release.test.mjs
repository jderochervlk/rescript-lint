import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { after, test } from "node:test";
import targets from "../../npm/targets.json" with { type: "json" };
import manifest from "../../npm/package.json" with { type: "json" };
import { packageName } from "../../npm/lib/platform.mjs";
import { releasePackages, stageRelease } from "../../scripts/npm/stage-release.mjs";
import { createNpmStageAdapter } from "../../scripts/npm/stage-release-npm.mjs";

const packages = releasePackages({ targets, manifest, artifacts: "/artifacts" });
const artifactDirectory = mkdtempSync(join(tmpdir(), "stage-release-artifacts-"));
const stageablePackages = packages.map((entry, index) => {
  const tarball = join(artifactDirectory, `${index}.tgz`);
  const contents = `fixture artifact ${entry.name}`;
  writeFileSync(tarball, contents);
  return {
    ...entry, tarball,
    digest: `sha512-${createHash("sha512").update(contents).digest("base64")}`,
  };
});
after(() => rmSync(artifactDirectory, { recursive: true, force: true }));
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
  const checked = await stageRelease({ packages: stageablePackages, env,
    exists: path => { events.push(["artifact", path]); return true; },
    request: async url => { events.push(["auth", String(url)]); return request(url); },
    stage: entry => { events.push(["stage", entry.name]); return { _tag: "PackageStaged" }; },
  });
  assert.deepEqual(checked, { _tag: "ReleaseStaged", packages: packages.map(entry => entry.name) });
  assert.deepEqual(events.slice(0, 6), stageablePackages.map(entry => ["artifact", entry.tarball]));
  assert.equal(events.slice(6, 13).every(([action]) => action === "auth"), true);
  assert.deepEqual(events.slice(13), packages.map(entry => ["stage", entry.name]));
});

test("invalid plans and missing artifacts fail before authentication or uploads", async () => {
  const base = { env, request: unexpected, stage: unexpected };
  assert.equal((await stageRelease({ ...base, packages: [], exists: unexpected }))._tag, "ReleaseInvalid");
  const checked = await stageRelease({ ...base, packages: stageablePackages,
    exists: path => path !== stageablePackages.at(-1).tarball });
  assert.equal(checked._tag, "ArtifactMissing");
  assert.match(checked.message, /Missing verified tarball for @jvlk\/rescript-lint:/);
});

test("an unconfigured publisher prevents all staging", async () => {
  const checked = await stageRelease({ packages: stageablePackages, env, exists: () => true, stage: unexpected,
    request: async url => String(url).includes("darwin-x64")
      ? { ok: false, status: 404 } : request(url),
  });
  assert.equal(checked._tag, "PublisherUnavailable");
  assert.match(checked.message, /darwin-x64.*HTTP 404/);
});

test("failed uploads stop later packages and retain the staged prefix for recovery", async () => {
  const uploaded = [];
  const checked = await stageRelease({ packages: stageablePackages, env, request, exists: () => true,
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

test("a staged response without a stage ID is inspected before any later upload", async () => {
  const events = [];
  const checked = await stageRelease({ packages: stageablePackages, env, request,
    exists: () => true,
    beginAttempt: () => { events.push("begin"); return { _tag: "AttemptStarted" }; },
    stage: entry => { events.push(`stage:${entry.name}`); return { _tag: "PackageStaged" }; },
    onAccepted: entry => events.push(`accepted:${entry.name}`),
    inspectAttempt: message => { events.push(`inspect:${message}`); },
  });
  assert.equal(checked._tag, "StageOutcomeUnknown");
  assert.deepEqual(events, ["begin", `stage:${packages[0].name}`,
    `inspect:${checked.message}`]);
  assert.match(checked.message, /lacks a stage ID/);
});

test("a mismatched supplied digest fails before authentication, ledger claim, or upload", async () => {
  const events = [];
  const changed = stageablePackages.map((entry, index) => index === 0
    ? { ...entry, digest: "sha512-not-the-fixture-digest" } : entry);
  const checked = await stageRelease({ packages: changed, env,
    exists: () => { events.push("exists"); return true; },
    request: () => { events.push("auth"); return request("https://registry.example"); },
    beginAttempt: () => { events.push("begin"); return { _tag: "AttemptStarted" }; },
    stage: () => { events.push("stage"); },
  });
  assert.equal(checked._tag, "StagingFailed");
  assert.deepEqual(events, Array(stageablePackages.length).fill("exists"));
  assert.match(checked.message, /Inspect npm stage list/);
});

test("an accepted-prefix progress failure is inspected and never resumes uploads", async () => {
  const events = [];
  const checked = await stageRelease({ packages: stageablePackages, env, request,
    exists: () => true,
    beginAttempt: () => { events.push("begin"); return { _tag: "AttemptStarted" }; },
    stage: entry => {
      events.push(`stage:${entry.name}`);
      return { _tag: "PackageStaged", stageId: `stage-${entry.name}` };
    },
    onAccepted: entry => {
      events.push(`progress:${entry.name}`);
      if (entry.name === packages[1].name) throw new Error("fixture-secret");
    },
    inspectAttempt: message => { events.push(`inspect:${message}`); },
  });
  assert.equal(checked._tag, "StagingFailed");
  assert.deepEqual(events, ["begin", `stage:${packages[0].name}`,
    `progress:${packages[0].name}`, `stage:${packages[1].name}`,
    `progress:${packages[1].name}`,
    "inspect:Protocol failure after 2 accepted package(s); inspect before retrying."]);
  assert.doesNotMatch(checked.message, /fixture-secret/);
});

test("inspection callback failure returns a manual-inspection error without leaking secrets", async () => {
  const checked = await stageRelease({ packages: stageablePackages, env, request,
    exists: () => true,
    beginAttempt: () => ({ _tag: "AttemptStarted" }),
    stage: () => { throw new Error("fixture-secret"); },
    inspectAttempt: () => { throw new Error("inspection-secret"); },
  });
  assert.equal(checked._tag, "StagingFailed");
  assert.match(checked.message, /Manual inspection required/);
  assert.doesNotMatch(checked.message, /fixture-secret|inspection-secret/);
});

test("completion failure inspects the fully uploaded release and never reports success", async () => {
  const events = [];
  const checked = await stageRelease({ packages: stageablePackages, env, request,
    exists: () => true,
    beginAttempt: () => { events.push("begin"); return { _tag: "AttemptStarted" }; },
    stage: entry => {
      events.push(`stage:${entry.name}`);
      return { _tag: "PackageStaged", stageId: `stage-${entry.name}` };
    },
    onAccepted: entry => { events.push(`accepted:${entry.name}`); },
    completeAttempt: () => { events.push("complete"); throw new Error("fixture-secret"); },
    inspectAttempt: message => { events.push(`inspect:${message}`); },
  });
  assert.equal(checked._tag, "StagingFailed");
  assert.deepEqual(events, ["begin",
    ...packages.flatMap(entry => [`stage:${entry.name}`, `accepted:${entry.name}`]),
    "complete",
    "inspect:Protocol failure after 6 accepted package(s); inspect before retrying."]);
  assert.doesNotMatch(checked.message, /fixture-secret/);
});

test("filesystem and command exceptions become errors without exposing credentials", async () => {
  for (const boundary of ["exists", "stage"]) {
    const fail = () => { throw new Error("fixture-secret"); };
    const checked = await stageRelease({ packages: stageablePackages, env, request, exists: () => true,
      stage: () => ({ _tag: "PackageStaged" }), [boundary]: fail });
    assert.equal(checked._tag, "StagingFailed");
    assert.doesNotMatch(checked.message, /fixture-secret/);
    assert.match(checked.message, /Inspect npm stage list/);
  }
});

test("the production npm JSON adapter stages all six packages native-first and verifies integrity", async () => {
  const calls = [];
  const adapter = createNpmStageAdapter({
    execPath: process.execPath, npmExecPath: "npm-cli.js", version: manifest.version,
    run: (_program, args, options) => {
      calls.push({ args, options });
      const entry = stageablePackages.find(pkg => pkg.tarball === args[3]);
      return {
        status: 0,
        stdout: JSON.stringify({ [entry.name]: {
          name: entry.name, version: manifest.version, integrity: entry.digest,
          stageId: `stage-${calls.length}`,
        } }),
      };
    },
  });
  const result = await stageRelease({
    packages: stageablePackages, env, request, exists: () => true, stage: adapter,
  });
  assert.equal(result._tag, "ReleaseStaged");
  assert.deepEqual(result.packages, packages.map(entry => entry.name));
  assert.equal(calls.length, 6);
  for (const [index, call] of calls.entries()) {
    assert.deepEqual(call.args, [
      "npm-cli.js", "stage", "publish", stageablePackages[index].tarball,
      "--json", "--access", "public", "--tag", "alpha", "--ignore-scripts",
    ]);
  }
  assert.equal(calls.every(call => call.options.timeout === 120_000), true);
});

test("npm JSON stage adapter treats failures, malformed output, and mismatched evidence as unsafe", async () => {
  const entry = { ...stageablePackages[0], digest: `sha512-${Buffer.alloc(64, 1).toString("base64")}` };
  const create = (status, stdout) => createNpmStageAdapter({
    execPath: process.execPath, npmExecPath: "npm-cli.js", version: manifest.version,
    run: () => ({ status, stdout }),
  });
  assert.equal((await create(1, "")(entry))._tag, "StagingFailed");
  assert.equal((await create(null, "")(entry))._tag, "StagingFailed");
  assert.equal((await create(0, "not json")(entry))._tag, "StageOutcomeUnknown");
  const wrongIntegrity = JSON.stringify({ [entry.name]: {
    name: entry.name, version: manifest.version, integrity: "sha512-wrong", stageId: "stage-1",
  } });
  assert.equal((await create(0, wrongIntegrity)(entry))._tag, "StageOutcomeUnknown");
  for (const evidence of [
    { name: "@wrong/package", version: manifest.version, integrity: entry.digest, stageId: "stage-1" },
    { name: entry.name, version: "0.1.0-alpha.21", integrity: entry.digest, stageId: "stage-1" },
    { name: entry.name, version: manifest.version, integrity: entry.digest, stageId: "" },
  ]) {
    assert.equal((await create(0, JSON.stringify({ [entry.name]: evidence }))(entry))._tag,
      "StageOutcomeUnknown");
  }
  const noNpm = createNpmStageAdapter({
    execPath: process.execPath, npmExecPath: undefined, version: manifest.version,
  });
  assert.equal((await noNpm(entry))._tag, "StagingFailed");
});

test("CLI refuses uploads without explicit trusted staging authorization", () => {
  const script = new URL("../../scripts/npm/stage-release-cli.mjs", import.meta.url);
  const environment = { ...process.env, npm_execpath: "fixture-npm-cli.js" };
  delete environment.RELEASE_STAGE;
  const result = spawnSync(process.execPath, [fileURLToPath(script)], {
    encoding: "utf8", env: environment,
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /requires RELEASE_STAGE=true/);
  assert.equal(result.stdout, "");
});

test("workflow requires staged publishing support and never approves or installs releases", () => {
  const workflow = readFileSync(new URL("../../.github/workflows/release.yml", import.meta.url), "utf8");
  assert.match(workflow, /npm@11\.15\.0/);
  assert.match(workflow, /inputs\.stage/);
  assert.match(workflow, /run: npm run stage:release/);
  assert.doesNotMatch(workflow, /npm publish|npm stage approve|npm exec|inputs\.publish/);
});
