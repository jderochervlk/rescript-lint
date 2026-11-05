import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

export function createTargetEvidence({ root, sourceSha, runId, version, targetId, execute = spawnSync }) {
  const workspace = resolve(root);
  const targets = JSON.parse(readFileSync(join(workspace, "npm/targets.json"), "utf8"));
  const manifest = JSON.parse(readFileSync(join(workspace, "npm/package.json"), "utf8"));
  if (!/^[a-f0-9]{40}$/.test(sourceSha) || !/^\d+$/.test(runId) ||
      manifest.version !== version) throw new Error("Invalid release artifact identity");
  const sourceHead = execute("git", ["rev-parse", "HEAD"], { cwd: workspace, encoding: "utf8" });
  if (sourceHead.error || sourceHead.status !== 0 || sourceHead.stdout.trim() !== sourceSha) {
    throw new Error("Artifact source checkout does not match its selected SHA");
  }
  const targetIndex = targets.findIndex(target => target.id === targetId);
  if (targetIndex < 0) throw new Error(`Unknown release target ${targetId}`);
  const packageEntries = [{
    name: `@jvlk/rescript-lint-${targetId}`,
    path: `jvlk-rescript-lint-${targetId}-${version}.tgz`,
    kind: "native",
  }];
  if (targetIndex === 0) packageEntries.push({
    name: manifest.name, path: `jvlk-rescript-lint-${version}.tgz`, kind: "launcher",
  });
  const packages = packageEntries.map(entry => {
    const path = join(workspace, "dist/npm", targetId, entry.path);
    const archiveManifest = readArchiveManifest(path, execute);
    verifyArchiveManifest(archiveManifest, entry, targets[targetIndex], targets, manifest, version);
    return {
      name: entry.name, file: entry.path,
      digest: `sha512-${createHash("sha512").update(readFileSync(path)).digest("base64")}`,
    };
  });
  return { schema: 1, sourceSha, runId, version, targetId, packages };
}

export function validateTargetEvidence({ evidence, expected, targets, manifest, artifacts, execute = spawnSync }) {
  if (evidence?.schema !== 1 || evidence.sourceSha !== expected.sourceSha ||
      evidence.runId !== expected.runId || evidence.version !== expected.version ||
      evidence.targetId !== expected.targetId || !Array.isArray(evidence.packages)) {
    throw new Error("Release artifact provenance does not match this selected run");
  }
  const targetIndex = targets.findIndex(target => target.id === expected.targetId);
  if (targetIndex < 0) throw new Error("Release artifact target is not canonical");
  const expectedEntries = [{
    name: `@jvlk/rescript-lint-${expected.targetId}`,
    file: `jvlk-rescript-lint-${expected.targetId}-${expected.version}.tgz`, kind: "native",
  }];
  if (targetIndex === 0) expectedEntries.push({
    name: manifest.name, file: `jvlk-rescript-lint-${expected.version}.tgz`, kind: "launcher",
  });
  if (evidence.packages.length !== expectedEntries.length) {
    throw new Error("Release artifact has an unexpected package set");
  }
  return expectedEntries.map((entry, index) => {
    const actual = evidence.packages[index];
    if (actual?.name !== entry.name || actual.file !== entry.file ||
        !/^sha512-[A-Za-z0-9+/]{86}==$/.test(actual.digest) ||
        Buffer.from(actual.digest.slice(7), "base64").length !== 64) {
      throw new Error("Release artifact package evidence is invalid");
    }
    const path = join(artifacts, `packages-${expected.targetId}`, entry.file);
    const digest = `sha512-${createHash("sha512").update(readFileSync(path)).digest("base64")}`;
    if (digest !== actual.digest) throw new Error(`Release artifact digest mismatch for ${entry.name}`);
    const archiveManifest = readArchiveManifest(path, execute);
    verifyArchiveManifest(archiveManifest, entry, targets[targetIndex], targets, manifest, expected.version);
    return { name: entry.name, tarball: path, digest };
  });
}

function readArchiveManifest(path, execute) {
  // A Windows drive prefix in the archive argument is a remote host to GNU tar.
  const result = execute("tar", ["-xOf", basename(path), "package/package.json"], {
    cwd: dirname(path), encoding: "utf8",
  });
  if (result.error || result.status !== 0) {
    throw new Error(`Cannot read package manifest from ${path}: ${result.error?.message ?? result.stderr}`);
  }
  try {
    return JSON.parse(result.stdout);
  } catch {
    throw new Error(`Invalid package manifest in ${path}`);
  }
}

function verifyArchiveManifest(actual, entry, target, targets, manifest, version) {
  if (actual.name !== entry.name || actual.version !== version) {
    throw new Error(`Tarball identity mismatch for ${entry.name}`);
  }
  if (entry.kind === "native" &&
      (JSON.stringify(actual.os) !== JSON.stringify([target.os]) ||
       JSON.stringify(actual.cpu) !== JSON.stringify([target.cpu]) ||
       JSON.stringify(actual.libc ?? []) !== JSON.stringify(target.libc ? [target.libc] : []))) {
    throw new Error(`Native target mismatch for ${entry.name}`);
  }
  if (entry.kind === "launcher") {
    const optional = Object.fromEntries(targets.map(item => [
      `@jvlk/rescript-lint-${item.id}`, version,
    ]));
    if (JSON.stringify(actual.optionalDependencies) !== JSON.stringify(optional) ||
        actual.name !== manifest.name) throw new Error("Launcher optional dependency set is mismatched");
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [root, sourceSha, runId, version, targetId] = process.argv.slice(2);
  const evidence = createTargetEvidence({ root, sourceSha, runId, version, targetId });
  const path = join(root, "dist/npm", targetId, "release-evidence.json");
  writeFileSync(path, `${JSON.stringify(evidence, null, 2)}\n`);
  process.stdout.write(`Verified ${evidence.packages.length} artifact(s) for ${targetId}.\n`);
}
