import assert from "node:assert/strict";
import { stageRelease } from "../../scripts/npm/stage-release.mjs";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { test } from "node:test";
import manifest from "../../npm/package.json" with { type: "json" };
import targets from "../../npm/targets.json" with { type: "json" };
import {
  createTargetEvidence, validateTargetEvidence,
} from "../../scripts/npm/alpha-staging-artifacts.mjs";

const sourceSha = "a".repeat(40);
const runId = "12345";
const version = manifest.version;
const targetName = target => `@jvlk/rescript-lint-${target.id}`;

function fixture() {
  const root = mkdtempSync(join(process.cwd(), ".alpha-artifacts-test-"));
  mkdirSync(join(root, "npm"), { recursive: true });
  mkdirSync(join(root, "dist/npm"), { recursive: true });
  writeFileSync(join(root, "npm/targets.json"), JSON.stringify(targets));
  writeFileSync(join(root, "npm/package.json"), JSON.stringify(manifest));
  const manifests = new Map();
  for (const target of targets) {
    const directory = join(root, "artifacts", `packages-${target.id}`);
    const sourceDirectory = join(root, "dist/npm", target.id);
    mkdirSync(directory, { recursive: true });
    mkdirSync(sourceDirectory, { recursive: true });
    const entries = [{
      name: targetName(target),
      file: `jvlk-rescript-lint-${target.id}-${version}.tgz`,
      manifest: {
        name: targetName(target), version, os: [target.os], cpu: [target.cpu],
        ...(target.libc ? { libc: [target.libc] } : {}),
      },
    }];
    if (target === targets[0]) entries.push({
      name: manifest.name, file: `jvlk-rescript-lint-${version}.tgz`,
      manifest: {
        name: manifest.name, version,
        optionalDependencies: Object.fromEntries(targets.map(item => [targetName(item), version])),
      },
    });
    for (const entry of entries) {
      writeFileSync(join(directory, entry.file), entry.file);
      manifests.set(join(directory, entry.file), entry.manifest);
      writeFileSync(join(sourceDirectory, entry.file), entry.file);
      manifests.set(join(sourceDirectory, entry.file), entry.manifest);
    }
  }
  const execute = (_command, _args) => {
    if (_command === "git") return { status: 0, stdout: `${sourceSha}\n` };
    const tarball = _args[1];
    return { status: 0, stdout: JSON.stringify(manifests.get(tarball)) };
  };
  const evidence = targets.map(target => createTargetEvidence({
    root, sourceSha, runId, version, targetId: target.id,
    execute: (command, args, options) => {
      if (command === "git") return { status: 0, stdout: `${sourceSha}\n` };
      return { status: 0, stdout: JSON.stringify(manifests.get(args[1])) };
    },
  }));
  return { root, manifests, execute, evidence };
}

test("artifact evidence binds source, run, target, package set, tarball digest, and archive manifest", () => {
  const data = fixture();
  try {
    for (const [index, target] of targets.entries()) {
      const verified = validateTargetEvidence({
        evidence: data.evidence[index],
        expected: { sourceSha, runId, version, targetId: target.id },
        targets, manifest, artifacts: join(data.root, "artifacts"), execute: data.execute,
      });
      assert.equal(verified.length, index === 0 ? 2 : 1);
    }
  } finally {
    rmSync(data.root, { recursive: true, force: true });
  }
});

test("mismatched provenance, package metadata, digest, and target fail before staging", async () => {
  const data = fixture();
  try {
    const original = data.evidence[0];
    const mutations = [
      { ...original, sourceSha: "b".repeat(40) },
      { ...original, runId: "999" },
      { ...original, targetId: targets[1].id },
      { ...original, packages: [{ ...original.packages[0], name: "@wrong/name" }, original.packages[1]] },
      { ...original, packages: [{ ...original.packages[0], digest: `sha512-${Buffer.alloc(64, 9).toString("base64")}` }, original.packages[1]] },
      { ...original, packages: [original.packages[0]] },
      { ...original, packages: [original.packages[1], original.packages[0]] },
    ];
    let stageCalls = 0;
    let ledgerClaims = 0;
    const attempt = async evidence => {
      const packages = validateTargetEvidence({
        evidence, expected: { sourceSha, runId, version, targetId: targets[0].id },
        targets, manifest, artifacts: join(data.root, "artifacts"), execute: data.execute,
      });
      return stageRelease({
        packages, env: {
          ACTIONS_ID_TOKEN_REQUEST_URL: "https://oidc.example/token",
          ACTIONS_ID_TOKEN_REQUEST_TOKEN: "test",
        },
        request: async url => ({
          ok: true,
          json: async () => String(url).includes("oidc.example")
            ? { value: "oidc-test" } : { token: "npm-test" },
        }),
        exists: () => true,
        beginAttempt: () => { ledgerClaims += 1; },
        stage: () => { stageCalls += 1; return { _tag: "PackageStaged", stageId: "accepted" }; },
      });
    };
    for (const evidence of mutations) {
      await assert.rejects(attempt(evidence));
    }
    assert.equal(stageCalls, 0);
    assert.equal(ledgerClaims, 0);
  } finally {
    rmSync(data.root, { recursive: true, force: true });
  }
});

test("target evidence is produced only from matching checked-out source and package versions", () => {
  const data = fixture();
  try {
    assert.throws(() => createTargetEvidence({
      root: data.root, sourceSha: "b".repeat(40), runId, version, targetId: targets[0].id,
      execute: () => ({ status: 0, stdout: `${sourceSha}\n` }),
    }), /does not match its selected SHA/);
    assert.throws(() => createTargetEvidence({
      root: data.root, sourceSha, runId, version: "0.1.0-alpha.23",
      targetId: targets[0].id, execute: () => ({ status: 0, stdout: `${sourceSha}\n` }),
    }), /Invalid release artifact identity/);
  } finally {
    rmSync(data.root, { recursive: true, force: true });
  }
});

test("archive decoding rejects failed tar commands, invalid JSON, and mismatched native/launcher manifests", () => {
  const data = fixture();
  try {
    const expected = { sourceSha, runId, version, targetId: targets[0].id };
    const archiveFailure = () => ({ status: 1, stderr: "fixture tar error" });
    assert.throws(() => validateTargetEvidence({
      evidence: data.evidence[0], expected, targets, manifest,
      artifacts: join(data.root, "artifacts"), execute: archiveFailure,
    }), /Cannot read package manifest/);
    const tarSpawnFailure = () => ({ error: new Error("tar unavailable"), status: null });
    assert.throws(() => validateTargetEvidence({
      evidence: data.evidence[0], expected, targets, manifest,
      artifacts: join(data.root, "artifacts"), execute: tarSpawnFailure,
    }), /Cannot read package manifest/);
    const invalidJson = () => ({ status: 0, stdout: "{" });
    assert.throws(() => validateTargetEvidence({
      evidence: data.evidence[0], expected, targets, manifest,
      artifacts: join(data.root, "artifacts"), execute: invalidJson,
    }), /Invalid package manifest/);
    const nativeMismatches = [
      pkg => ({ ...pkg, version: "0.1.0-alpha.21" }),
      pkg => ({ ...pkg, os: ["win32"] }),
      pkg => ({ ...pkg, cpu: ["arm64"] }),
      pkg => ({ ...pkg, libc: ["musl"] }),
    ];
    for (const change of nativeMismatches) {
      assert.throws(() => validateTargetEvidence({
        evidence: data.evidence[0], expected, targets, manifest,
        artifacts: join(data.root, "artifacts"),
        execute: (_command, args) => {
          const actual = JSON.parse(readFileSync(args[1] + ".manifest.json", "utf8"));
          return { status: 0, stdout: JSON.stringify(change(actual)) };
        },
      }));
    }
    assert.throws(() => validateTargetEvidence({
      evidence: data.evidence[0], expected, targets, manifest,
      artifacts: join(data.root, "artifacts"),
      execute: (_command, args) => {
        const actual = data.manifests.get(args[1]);
        const changed = args[1].endsWith(`jvlk-rescript-lint-${version}.tgz`)
          ? { ...actual, optionalDependencies: {} } : actual;
        return { status: 0, stdout: JSON.stringify(changed) };
      },
    }), /Launcher optional dependency set/);
  } finally {
    rmSync(data.root, { recursive: true, force: true });
  }
});

test("artifact evidence CLI writes target metadata for real local archives", () => {
  const source = mkdtempSync(join(process.cwd(), ".alpha-artifact-cli-test-"));
  const repository = join(source, "npm");
  const target = targets[0];
  mkdirSync(repository, { recursive: true });
  writeFileSync(join(repository, "package.json"), JSON.stringify(manifest));
  writeFileSync(join(repository, "targets.json"), JSON.stringify(targets));
  const packageRoot = join(source, "package");
  mkdirSync(packageRoot, { recursive: true });
  writeFileSync(join(packageRoot, "package.json"), JSON.stringify({
    name: targetName(target), version,
    os: [target.os], cpu: [target.cpu], libc: [target.libc],
  }));
  const destination = join(source, "dist/npm", target.id);
  mkdirSync(destination, { recursive: true });
  const tarball = join(destination, `jvlk-rescript-lint-${target.id}-${version}.tgz`);
  const packed = spawnSync("tar", ["-czf", tarball, "-C", source, "package"], { encoding: "utf8" });
  assert.equal(packed.status, 0, packed.stderr);
  const launcherRoot = join(source, "launcher");
  mkdirSync(launcherRoot, { recursive: true });
  writeFileSync(join(launcherRoot, "package.json"), JSON.stringify({
    name: manifest.name, version,
    optionalDependencies: Object.fromEntries(targets.map(item => [targetName(item), version])),
  }));
  const launcherPackageRoot = join(source, "package");
  writeFileSync(join(launcherPackageRoot, "package.json"), readFileSync(join(launcherRoot, "package.json"), "utf8"));
  const launcherTarball = join(destination, `jvlk-rescript-lint-${version}.tgz`);
  const launcherPacked = spawnSync("tar", ["-czf", launcherTarball, "-C", source, "package"], { encoding: "utf8" });
  assert.equal(launcherPacked.status, 0, launcherPacked.stderr);
  const initialized = spawnSync("git", ["init", "-q"], { cwd: source });
  assert.equal(initialized.status, 0);
  spawnSync("git", ["config", "user.email", "fixture@example.com"], { cwd: source });
  spawnSync("git", ["config", "user.name", "Fixture"], { cwd: source });
  spawnSync("git", ["add", "."], { cwd: source });
  const committed = spawnSync("git", ["commit", "-qm", "fixture"], { cwd: source });
  assert.equal(committed.status, 0, committed.stderr);
  const sha = spawnSync("git", ["rev-parse", "HEAD"], { cwd: source, encoding: "utf8" }).stdout.trim();
  const script = new URL("../../scripts/npm/alpha-staging-artifacts.mjs", import.meta.url);
  const generated = spawnSync(process.execPath, [script.pathname, source, sha, "101", version, target.id], {
    encoding: "utf8",
  });
  assert.equal(generated.status, 0, generated.stderr);
  assert.equal(readFileSync(join(destination, "release-evidence.json"), "utf8").includes(sha), true);
  rmSync(source, { recursive: true, force: true });
});
