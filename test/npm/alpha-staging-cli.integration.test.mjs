import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import {
  appendFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync,
} from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import manifest from "../../npm/package.json" with { type: "json" };
import targets from "../../npm/targets.json" with { type: "json" };
import { paths } from "../../scripts/version/version.mjs";

const root = fileURLToPath(new URL("../../", import.meta.url));
const cli = fileURLToPath(new URL("../../scripts/npm/stage-release-cli.mjs", import.meta.url));
const sourceSha = "a".repeat(40);
const runId = "101";
const version = "0.1.0-alpha.23";
const artifactRoot = join(root, "artifacts");
const nativeName = target => `@jvlk/rescript-lint-${target.id}`;

function makeSource(directory) {
  for (const path of paths) {
    const contents = readFileSync(join(root, path), "utf8").replaceAll(manifest.version, version);
    const destination = join(directory, path);
    mkdirSync(join(destination, ".."), { recursive: true });
    writeFileSync(destination, contents);
  }
  mkdirSync(join(directory, "npm"), { recursive: true });
  writeFileSync(join(directory, "npm/targets.json"), JSON.stringify(targets, null, 2));
}

function makeArtifacts() {
  mkdirSync(artifactRoot, { recursive: true });
  const evidence = [];
  const artifactFiles = [];
  for (const target of targets) {
    const directory = join(artifactRoot, `packages-${target.id}`);
    mkdirSync(directory, { recursive: true });
    const items = [{
      name: nativeName(target),
      filename: `jvlk-rescript-lint-${target.id}-${version}.tgz`,
      packageManifest: {
        name: nativeName(target), version, os: [target.os], cpu: [target.cpu],
        ...(target.libc ? { libc: [target.libc] } : {}),
      },
    }];
    if (target.id === "linux-x64-gnu") {
      items.push({
        name: manifest.name,
        filename: `jvlk-rescript-lint-${version}.tgz`,
        packageManifest: {
          name: manifest.name, version,
          optionalDependencies: Object.fromEntries(targets.map(item => [nativeName(item), version])),
        },
      });
    }
    const packageEvidence = items.map(item => {
      const path = join(directory, item.filename);
      writeFileSync(path, `fixture tarball for ${item.name}`);
      writeFileSync(`${path}.manifest.json`, JSON.stringify(item.packageManifest));
      artifactFiles.push(path, `${path}.manifest.json`);
      return {
        name: item.name, file: item.filename,
        digest: `sha512-${createHash("sha512").update(readFileSync(path)).digest("base64")}`,
      };
    });
    const metadata = {
      schema: 1, sourceSha, runId, version, targetId: target.id, packages: packageEvidence,
    };
    const evidencePath = join(directory, "release-evidence.json");
    writeFileSync(evidencePath, JSON.stringify(metadata));
    artifactFiles.push(evidencePath);
    evidence.push(metadata);
  }
  return { evidence, artifactFiles };
}

function preload() {
  return `
    import fs from "node:fs";
    import child from "node:child_process";
    import crypto from "node:crypto";
    import { syncBuiltinESMExports } from "node:module";
    const stateFile = process.env.FIXTURE_STATE_FILE;
    const stageLog = process.env.FIXTURE_STAGE_LOG;
    const sourceSha = process.env.FIXTURE_ACTUAL_SHA ?? process.env.RELEASE_SOURCE_SHA;
    const empty = { schema: 1, cutoff: "0.1.0-alpha.22", releases: [] };
    let state = fs.existsSync(stateFile) ? JSON.parse(fs.readFileSync(stateFile, "utf8"))
      : { tip: "1".repeat(40), ledger: empty, parent: undefined };
    let blobContent;
    let pendingSha;
    let stageCount = 0;
    let contentReadCount = 0;
    child.spawnSync = (command, args, options = {}) => {
      if (command === "git" && args[0] === "rev-parse") {
        return Number(process.env.FIXTURE_GIT_FAILURE) === 1
          ? { status: 1, stdout: "" } : { status: 0, stdout: sourceSha + "\\n" };
      }
      if (command === "tar") return { status: 0, stdout: fs.readFileSync(args[1] + ".manifest.json", "utf8") };
      if (command === process.execPath && args[0] === process.env.npm_execpath) {
        stageCount += 1;
        fs.appendFileSync(stageLog, stageCount + "\\n");
        if (Number(process.env.FIXTURE_FAIL_AT) === stageCount) return { status: 1, stderr: "private fixture error" };
        const tarball = args[3];
        const pkg = JSON.parse(fs.readFileSync(tarball + ".manifest.json", "utf8"));
        const integrity = "sha512-" + crypto.createHash("sha512").update(fs.readFileSync(tarball)).digest("base64");
        const accepted = Number(process.env.FIXTURE_UNKNOWN_AT) !== stageCount;
        return {
          status: 0,
          stdout: JSON.stringify({ [pkg.name]: {
            name: pkg.name, version: pkg.version, integrity,
            ...(accepted ? { stageId: "stage-" + stageCount } : {}),
          } }),
        };
      }
      if (command === "gh") {
        if (process.env.FIXTURE_API_FAILURE === "true") {
          return { status: 1, stderr: "fixture API failure" };
        }
        const path = args[1];
        const methodIndex = args.indexOf("--method");
        const method = methodIndex < 0 ? "GET" : args[methodIndex + 1];
        const data = options.input ? JSON.parse(options.input) : undefined;
        let value;
        if (path.includes("/git/ref/heads/automation/alpha-staging-state")) {
          value = { object: { sha: state.tip } };
        } else if (path.includes("/git/commits/")) {
          value = { sha: state.tip, tree: { sha: "tree" },
            parents: state.parent ? [{ sha: state.parent }] : [] };
        } else if (path.includes("/git/trees/")) {
          value = { truncated: false, tree: [{ path: "alpha-staging-ledger.json", type: "blob", mode: "100644" }] };
        } else if (path.includes("/contents/alpha-staging-ledger.json")) {
          contentReadCount += 1;
          const ledger = JSON.parse(JSON.stringify(state.ledger));
          if (contentReadCount === Number(process.env.FIXTURE_CORRUPT_AT_READ)) {
            const release = ledger.releases[0];
            switch (process.env.FIXTURE_CORRUPT_FIELD) {
              case "sourceSha": release.sourceSha = "b".repeat(40); break;
              case "pullRequest": release.pullRequest = 999; break;
              case "attemptId": release.attemptId = "different-attempt"; break;
              case "runId": release.runId = "102"; break;
              case "originalRun": release.originalRun = 102; break;
              case "status": release.status = "NeedsInspection"; release.reason = "fixture"; break;
              case "accepted": release.accepted = [{name: release.packages[0].name, stageId: "prior"}]; break;
              case "digest": release.packages[0].digest = "sha512-" + Buffer.alloc(64, 9).toString("base64"); break;
              case "artifact": release.packages[0].artifact = "another-artifact.tgz"; break;
              case "missing": ledger.releases = []; break;
              default: break;
            }
          }
          value = { encoding: "base64", content: Buffer.from(JSON.stringify(ledger)).toString("base64") };
        } else if (path.endsWith("/git/blobs") && method === "POST") {
          blobContent = data.content;
          value = { sha: "blob" };
        } else if (path.endsWith("/git/trees") && method === "POST") {
          value = { sha: "tree-new" };
        } else if (path.endsWith("/git/commits") && method === "POST") {
          pendingSha = (Number.parseInt(state.tip.slice(0, 2), 16) + 1).toString(16).padStart(2, "0") + state.tip.slice(2);
          value = { sha: pendingSha, parents: data.parents.map(sha => ({ sha })) };
        } else if (path.includes("/git/refs/heads/") && method === "PATCH") {
          state = { tip: pendingSha, ledger: JSON.parse(blobContent), parent: state.tip };
          fs.writeFileSync(stateFile, JSON.stringify(state));
          value = { ref: "refs/heads/automation/alpha-staging-state" };
        } else {
          return { status: 1, stderr: "Unexpected fixture API request" };
        }
        return { status: 0, stdout: JSON.stringify(value) };
      }
      return { status: 1, stderr: "Unexpected fixture command" };
    };
    globalThis.fetch = async url => {
      const unavailable = process.env.FIXTURE_NPM_AUTH_FAIL === "true" &&
        !String(url).includes("oidc.example");
      return {
        ok: !unavailable, status: unavailable ? 403 : 200,
        json: async () => String(url).includes("oidc.example")
          ? { value: "fixture-oidc" } : { token: "fixture-npm" },
      };
    };
    syncBuiltinESMExports();
  `;
}

function run(source, stateFile, stageLog, extraEnvironment = {}) {
  const env = {
    ...process.env,
    RELEASE_SOURCE_DIR: source,
    RELEASE_VERSION: version,
    RELEASE_SOURCE_SHA: sourceSha,
    RELEASE_PULL_REQUEST: "57",
    RELEASE_RUN_ID: runId,
    RELEASE_CUTOFF: "22",
    RELEASE_STAGE: "true",
    GH_TOKEN: "fixture-token",
    GITHUB_REPOSITORY: "jderochervlk/rescript-lint",
    GITHUB_ACTIONS: "true",
    GITHUB_WORKFLOW_REF: "jderochervlk/rescript-lint/.github/workflows/release.yml@refs/heads/main",
    GITHUB_REF: "refs/heads/main",
    GITHUB_REF_TYPE: "branch",
    GITHUB_REF_NAME: "main",
    GITHUB_EVENT_NAME: "workflow_dispatch",
    ACTIONS_ID_TOKEN_REQUEST_URL: "https://oidc.example/token",
    ACTIONS_ID_TOKEN_REQUEST_TOKEN: "fixture-oidc",
    npm_execpath: "fixture-npm-cli.js",
    FIXTURE_STATE_FILE: stateFile,
    FIXTURE_STAGE_LOG: stageLog,
    GITHUB_STEP_SUMMARY: `${stageLog}.summary.md`,
    ...extraEnvironment,
  };
  return spawnSync(process.execPath, [
    "--import", `data:text/javascript,${encodeURIComponent(preload())}`, cli,
  ], { cwd: root, encoding: "utf8", env });
}

test("actual staging CLI claims, rereads, uploads six in order, completes, and no-ops on duplicates", () => {
  assert.equal(existsSync(artifactRoot), false, "test fixture artifact directory must be absent");
  const directory = mkdtempSync(join(tmpdir(), "alpha-staging-cli-"));
  const source = join(directory, "source");
  const stateFile = join(directory, "ledger.json");
  const stageLog = join(directory, "stages.log");
  makeSource(source);
  const { artifactFiles } = makeArtifacts();
  try {
    const first = run(source, stateFile, stageLog);
    assert.equal(first.status, 0, first.stderr);
    assert.match(first.stdout, /All six packages are staged/);
    assert.match(first.stdout, /stage-1/);
    assert.match(first.stdout, /stage-6/);
    assert.match(first.stdout, /Ledger state: \*\*Staged\*\*/);
    const summary = readFileSync(`${stageLog}.summary.md`, "utf8");
    assert.match(summary, /Original staging run: 101/);
    assert.match(summary, /stage-6/);
    const state = JSON.parse(readFileSync(stateFile, "utf8"));
    assert.equal(state.ledger.releases[0].status, "Staged");
    assert.deepEqual(state.ledger.releases[0].packages.map(item => item.name), [
      ...targets.map(nativeName), manifest.name,
    ]);
    assert.equal(state.ledger.releases[0].accepted.length, 6);
    const duplicate = run(source, stateFile, stageLog);
    assert.equal(duplicate.status, 0, duplicate.stderr);
    assert.match(duplicate.stdout, /No-op:/);
    assert.match(duplicate.stdout, /original staging run|Original staging run/);
    assert.equal(readFileSync(stageLog, "utf8").trim().split("\n").length, 6);
  } finally {
    rmSync(artifactRoot, { recursive: true, force: true });
    rmSync(directory, { recursive: true, force: true });
  }
});

test("actual staging CLI marks failed and unknown responses for inspection without retrying", () => {
  assert.equal(existsSync(artifactRoot), false, "test fixture artifact directory must be absent");
  const directory = mkdtempSync(join(tmpdir(), "alpha-staging-partial-"));
  const source = join(directory, "source");
  const stateFile = join(directory, "ledger.json");
  const stageLog = join(directory, "stages.log");
  makeSource(source);
  makeArtifacts();
  try {
    const failed = run(source, stateFile, stageLog, { FIXTURE_FAIL_AT: "3" });
    assert.equal(failed.status, 2);
    assert.match(failed.stdout, /Ledger state: \*\*NeedsInspection\*\*/);
    assert.match(failed.stdout, /stage-1/);
    const state = JSON.parse(readFileSync(stateFile, "utf8"));
    assert.equal(state.ledger.releases[0].status, "NeedsInspection");
    assert.equal(state.ledger.releases[0].accepted.length, 2);
    assert.equal(readFileSync(stageLog, "utf8").trim().split("\n").length, 3);
  } finally {
    rmSync(artifactRoot, { recursive: true, force: true });
    rmSync(directory, { recursive: true, force: true });
  }

  assert.equal(existsSync(artifactRoot), false);
  const unknownDirectory = mkdtempSync(join(tmpdir(), "alpha-staging-unknown-"));
  const unknownSource = join(unknownDirectory, "source");
  const unknownState = join(unknownDirectory, "ledger.json");
  const unknownLog = join(unknownDirectory, "stages.log");
  makeSource(unknownSource);
  makeArtifacts();
  try {
    const unknown = run(unknownSource, unknownState, unknownLog, { FIXTURE_UNKNOWN_AT: "3" });
    assert.equal(unknown.status, 2);
    const state = JSON.parse(readFileSync(unknownState, "utf8"));
    assert.equal(state.ledger.releases[0].status, "NeedsInspection");
    assert.equal(state.ledger.releases[0].accepted.length, 2);
    assert.equal(readFileSync(unknownLog, "utf8").trim().split("\n").length, 3);
  } finally {
    rmSync(artifactRoot, { recursive: true, force: true });
    rmSync(unknownDirectory, { recursive: true, force: true });
  }
});

test("actual staging CLI rejects missing, moved, and untrusted release identity before any upload", () => {
  assert.equal(existsSync(artifactRoot), false, "test fixture artifact directory must be absent");
  const directory = mkdtempSync(join(tmpdir(), "alpha-staging-guards-"));
  const source = join(directory, "source");
  const stateFile = join(directory, "ledger.json");
  const stageLog = join(directory, "stages.log");
  makeSource(source);
  makeArtifacts();
  try {
    const cases = [
      [{ FIXTURE_GIT_FAILURE: "1" }, /does not match selected release SHA/],
      [{ RELEASE_SOURCE_SHA: "b".repeat(40), FIXTURE_ACTUAL_SHA: sourceSha }, /does not match selected release SHA/],
      [{ RELEASE_VERSION: "0.1.0-alpha.24" }, /does not match RELEASE_VERSION/],
      [{ RELEASE_STAGE: "false" }, /requires RELEASE_STAGE=true/],
      [{ GITHUB_ACTIONS: "false" }, /trusted release source and run identity/],
      [{ GITHUB_REPOSITORY: "attacker/repo" }, /trusted release source and run identity/],
      [{
        GITHUB_EVENT_NAME: "push", GITHUB_REF: "refs/tags/not-canonical",
        GITHUB_REF_TYPE: "tag", GITHUB_REF_NAME: "v0.1.0-alpha.23",
        GITHUB_WORKFLOW_REF: "jderochervlk/rescript-lint/.github/workflows/release.yml@refs/tags/not-canonical",
      }, /trusted release source and run identity/],
      [{ GITHUB_WORKFLOW_REF: "jderochervlk/rescript-lint/.github/workflows/other.yml@refs/heads/main" },
        /trusted release source and run identity/],
      [{ GH_TOKEN: "" }, /trusted release source and run identity/],
      [{ RELEASE_SOURCE_SHA: "invalid", FIXTURE_ACTUAL_SHA: "invalid" },
        /trusted release source and run identity/],
      [{ RELEASE_SOURCE_SHA: undefined }, /trusted release source and run identity/],
      [{ RELEASE_RUN_ID: "" }, /trusted release source and run identity/],
      [{ RELEASE_PULL_REQUEST: "0" }, /trusted release source and run identity/],
      [{ RELEASE_PULL_REQUEST: "invalid" }, /trusted release source and run identity/],
      [{ GITHUB_EVENT_NAME: "pull_request" }, /trusted release source and run identity/],
      [{
        GITHUB_EVENT_NAME: "push", GITHUB_REF: undefined,
        GITHUB_REF_TYPE: "tag", GITHUB_REF_NAME: "v0.1.0-alpha.23",
      }, /trusted release source and run identity/],
    ];
    for (const [extra, expected] of cases) {
      const rejected = run(source, stateFile, stageLog, extra);
      assert.notEqual(rejected.status, 0, rejected.stdout);
      assert.match(rejected.stderr, expected);
    }
    const wrongCutoff = run(source, stateFile, stageLog, { RELEASE_CUTOFF: "23" });
    assert.equal(wrongCutoff.status, 2);
    assert.match(wrongCutoff.stdout, /Release staging failed/);
    assert.equal(existsSync(stateFile), false);
    assert.equal(existsSync(stageLog), false);
    const apiFailure = run(source, stateFile, stageLog, { FIXTURE_API_FAILURE: "true" });
    assert.equal(apiFailure.status, 2);
    assert.match(apiFailure.stdout, /Release staging failed/);
    assert.equal(existsSync(stageLog), false);

    const allowedEvents = [
      {
        GITHUB_EVENT_NAME: "push", GITHUB_REF: "refs/heads/main",
        GITHUB_REF_TYPE: "branch", GITHUB_REF_NAME: "main",
        GITHUB_WORKFLOW_REF: "jderochervlk/rescript-lint/.github/workflows/release.yml@refs/heads/main",
      },
      {
        GITHUB_EVENT_NAME: "schedule", GITHUB_REF: "refs/heads/main",
        GITHUB_REF_TYPE: "branch", GITHUB_REF_NAME: "main",
        GITHUB_WORKFLOW_REF: "jderochervlk/rescript-lint/.github/workflows/release.yml@refs/heads/main",
      },
      {
        GITHUB_EVENT_NAME: "push", GITHUB_REF: "refs/tags/v0.1.0-alpha.23",
        GITHUB_REF_TYPE: "tag", GITHUB_REF_NAME: "v0.1.0-alpha.23",
        GITHUB_WORKFLOW_REF: "jderochervlk/rescript-lint/.github/workflows/release.yml@refs/tags/v0.1.0-alpha.23",
      },
    ];
    for (const allowedEvent of allowedEvents) {
      const noUpload = run(source, stateFile, stageLog, {
        ...allowedEvent, RELEASE_CUTOFF: "23",
      });
      assert.equal(noUpload.status, 2, noUpload.stderr);
      assert.match(noUpload.stdout, /Release staging failed/);
    }
    assert.equal(existsSync(stageLog), false);
  } finally {
    rmSync(artifactRoot, { recursive: true, force: true });
    rmSync(directory, { recursive: true, force: true });
  }
});

test("actual staging CLI refuses every mismatch found after its accepted claim reread", () => {
  assert.equal(existsSync(artifactRoot), false, "test fixture artifact directory must be absent");
  const directory = mkdtempSync(join(tmpdir(), "alpha-staging-readback-"));
  const source = join(directory, "source");
  makeSource(source);
  makeArtifacts();
  try {
    for (const field of [
      "missing", "attemptId", "sourceSha", "pullRequest", "runId", "originalRun",
      "status", "accepted", "digest", "artifact",
    ]) {
      const stateFile = join(directory, `${field}-ledger.json`);
      const stageLog = join(directory, `${field}-stages.log`);
      const result = run(source, stateFile, stageLog, {
        FIXTURE_CORRUPT_AT_READ: "4",
        FIXTURE_CORRUPT_FIELD: field,
      });
      assert.equal(result.status, 2, `${field}: ${result.stderr}`);
      assert.match(result.stdout, /Release staging failed/);
      assert.equal(existsSync(stageLog), false, `${field} must not upload before verified readback`);
    }
  } finally {
    rmSync(artifactRoot, { recursive: true, force: true });
    rmSync(directory, { recursive: true, force: true });
  }
});

test("actual staging CLI reports preflight failures without creating an attempt or requiring a step-summary file", () => {
  assert.equal(existsSync(artifactRoot), false, "test fixture artifact directory must be absent");
  const directory = mkdtempSync(join(tmpdir(), "alpha-staging-preflight-"));
  const source = join(directory, "source");
  const stateFile = join(directory, "ledger.json");
  const stageLog = join(directory, "stages.log");
  makeSource(source);
  makeArtifacts();
  try {
    const failed = run(source, stateFile, stageLog, {
      FIXTURE_NPM_AUTH_FAIL: "true",
      RELEASE_VERSION: undefined,
      GITHUB_STEP_SUMMARY: undefined,
    });
    assert.equal(failed.status, 2);
    assert.match(failed.stdout, /Ledger state: \*\*NoAttempt\*\*/);
    assert.match(failed.stdout, /No staging attempt was recorded/);
    assert.equal(existsSync(stateFile), false);
    assert.equal(existsSync(stageLog), false);
    assert.equal(existsSync(`${stageLog}.summary.md`), false);
  } finally {
    rmSync(artifactRoot, { recursive: true, force: true });
    rmSync(directory, { recursive: true, force: true });
  }
});
