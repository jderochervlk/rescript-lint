"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");
const { chmodSync, copyFileSync, cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } = require("node:fs");
const { tmpdir } = require("node:os");
const { dirname, join, resolve } = require("node:path");
const { spawnSync } = require("node:child_process");
const compliance = require("../../scripts/npm/compliance.cjs");
const dependencies = require("../../scripts/npm/dependencies.json");
const { stagePackages } = require("../../scripts/npm/package.cjs");
const { detectHost } = require("../../npm/lib/launcher.cjs");
const { selectTarget } = require("../../npm/lib/platform.cjs");
const root = resolve(__dirname, "../..");
const binary = join(root, "_build/default/bin/main.exe");
const sourceBundle = join(root, "dist/compliance/bundle");

function temporary(context) {
  const path = mkdtempSync(join(tmpdir(), "lint compliance "));
  context.after(() => rmSync(path, { recursive: true, force: true }));
  return path;
}

function fixture(context) {
  const path = temporary(context);
  for (const file of [...compliance.applicationFiles(root), "docs/REBUILD.md", "_build/default/bin/main.exe"]) {
    mkdirSync(dirname(join(path, file)), { recursive: true });
    copyFileSync(join(root, file), join(path, file));
  }
  const bundle = join(path, "dist/compliance/bundle");
  cpSync(sourceBundle, bundle, { recursive: true });
  return { root: path, binary: join(path, "_build/default/bin/main.exe"), bundle, destination: join(path, "staged") };
}

function refreshMetadata(bundle) {
  const path = join(bundle, "bundle.json");
  const metadata = JSON.parse(readFileSync(path, "utf8"));
  writeFileSync(path, JSON.stringify({ ...metadata,
    files: compliance.hashes(bundle, compliance.files(bundle).filter((file) => file !== "bundle.json")) }));
}

test("bundles all reviewed sources/licenses and stages them intact", (context) => {
  const input = fixture(context);
  writeFileSync(join(input.root, "lib", ".env"), "excluded fixture");
  assert.equal(compliance.applicationFiles(input.root).includes("lib/.env"), false);
  assert.equal(compliance.validateBundle(input.root, input.binary, input.bundle), undefined);
  assert.deepEqual(compliance.stageCompliance(input), { _tag: "ComplianceStaged" });
  assert.deepEqual(compliance.files(input.destination), compliance.files(input.bundle));
  assert.equal(dependencies.length, 13);
  assert.ok(compliance.requiredFiles().includes("licenses/flow_parser/src/hack_forked/utils/collections/third-party/LICENSE"));
});

for (const [name, change, message] of [
  ["missing notices", (input) => rmSync(join(input.bundle, "licenses/ocaml/LICENSE")), /material is missing/],
  ["modified notice", (input) => writeFileSync(join(input.bundle, "licenses/ocaml/LICENSE"), "changed"), /Bundle content changed/],
  ["modified binary", (input) => {
    chmodSync(input.binary, 0o755); writeFileSync(input.binary, "changed");
  }, /Binary changed/],
  ["modified source", (input) => writeFileSync(join(input.root, "lib/command.ml"), "changed"), /Application sources changed/],
  ["new source", (input) => writeFileSync(join(input.root, "lib/extra.ml"), "changed"), /Application sources changed/],
  ["modified instructions", (input) => writeFileSync(join(input.root, "docs/REBUILD.md"), "changed"), /Rebuild instructions changed/],
  ["inventory drift", (input) => {
    writeFileSync(join(input.bundle, "dependencies.json"), "[]"); refreshMetadata(input.bundle);
  }, /Dependency inventory changed/],
  ["archive corruption", (input) => {
    writeFileSync(join(input.bundle, "sources/rescript.tar.gz"), "changed"); refreshMetadata(input.bundle);
  }, /archive checksum mismatch/],
]) {
  test(`rejects ${name}`, (context) => {
    const input = fixture(context);
    change(input);
    const result = compliance.stageCompliance(input);
    assert.equal(result._tag, "ComplianceInvalid");
    assert.match(result.message, message);
    assert.equal(existsSync(input.destination), false);
  });
}

test("missing/malformed bundles and staging failures are errors as values", (context) => {
  const input = fixture(context);
  writeFileSync(input.destination, "not a directory");
  assert.equal(compliance.stageCompliance(input)._tag, "ComplianceUnavailable");
  writeFileSync(join(input.bundle, "bundle.json"), "not JSON");
  assert.equal(compliance.stageCompliance(input)._tag, "ComplianceUnavailable");
  rmSync(input.bundle, { recursive: true });
  assert.equal(compliance.stageCompliance(input)._tag, "ComplianceUnavailable");
  cpSync(join(root, "npm"), join(input.root, "npm"), { recursive: true });
  copyFileSync(join(root, "docs/DISTRIBUTION.md"), join(input.root, "docs/DISTRIBUTION.md"));
  const target = selectTarget(detectHost(process).host).target;
  assert.equal(stagePackages({ ...input, destination: join(input.root, "packages"), target })._tag, "ComplianceUnavailable");
});

test("command boundary and environment checks fail closed", async () => {
  const { command, verifyEnvironment } = await import("../../scripts/npm/compliance-prepare.mjs");
  assert.deepEqual(command("tool", [], root, () => ({ status: 0, stdout: " ok\n" })), { _tag: "Output", text: "ok" });
  for (const result of [{ status: 1, stderr: "failed" }, { status: null, error: "missing" }, { status: 2 }]) {
    assert.equal(command("tool", [], root, () => result)._tag, "CommandFailed");
  }
  const failure = { _tag: "CommandFailed", message: "failed" };
  assert.deepEqual(verifyEnvironment(root, () => failure), failure);
  assert.equal(verifyEnvironment(root, () => ({ _tag: "Output", text: "unexpected" }))._tag, "DependencyMismatch");
  assert.deepEqual(verifyEnvironment(root), { _tag: "EnvironmentChecked" });
});

test("downloads verify checksums before caching and recheck cached archives", async (context) => {
  const { archive } = await import("../../scripts/npm/compliance-prepare.mjs");
  const directory = temporary(context);
  const bytes = Buffer.from("source");
  const item = { name: "fixture", archive: "source.tgz", url: "https://example.invalid/source", algorithm: "sha256", digest: compliance.digest(bytes) };
  assert.equal((await archive(item, directory, async () => ({ ok: false, status: 503 })))._tag, "DownloadFailed");
  assert.equal((await archive(item, directory, async () => new Response("wrong")))._tag, "ChecksumMismatch");
  assert.equal(existsSync(join(directory, item.archive)), false);
  assert.equal((await archive(item, directory, async () => new Response(bytes)))._tag, "Archive");
  assert.equal((await archive(item, directory, () => assert.fail("cache must not fetch")))._tag, "Archive");
  writeFileSync(join(directory, item.archive), "bad cache");
  assert.equal((await archive(item, directory))._tag, "ChecksumMismatch");
});

test("archive and application tar command errors propagate", async (context) => {
  const { unpackNotices, finishBundle } = await import("../../scripts/npm/compliance-prepare.mjs");
  const directory = temporary(context);
  const failure = { _tag: "CommandFailed", message: "tar failed" };
  assert.deepEqual(unpackNotices(dependencies[0], "unused", directory, "unused", () => failure), failure);
  assert.deepEqual(finishBundle(root, binary, directory, () => failure), failure);
});

for (const file of ["lib/command.ml", "_build/default/bin/main.exe"]) {
  test(`preparation refuses concurrent changes to ${file}`, async (context) => {
    const { finishBundle } = await import("../../scripts/npm/compliance-prepare.mjs");
    const input = fixture(context);
    const result = finishBundle(input.root, input.binary, input.destination, () => {
      chmodSync(join(input.root, file), 0o755);
      writeFileSync(join(input.root, file), "changed during archiving");
      return { _tag: "Output", text: "" };
    });
    assert.equal(result._tag, "SourceChanged");
  });
}

test("preparation cleans temporary work and preserves the previous bundle on failures", async (context) => {
  const { prepareCompliance, command } = await import("../../scripts/npm/compliance-prepare.mjs");
  const input = fixture(context);
  const failure = { _tag: "CommandFailed", message: "unavailable" };
  assert.deepEqual(await prepareCompliance({ ...input, run: () => failure }), failure);
  const run = (program, args) => command(program, args, root);
  const failed = await prepareCompliance({ ...input, run, fetchSource: async () => ({ ok: false, status: 403 }) });
  assert.equal(failed._tag, "DownloadFailed");
  assert.ok(existsSync(join(input.bundle, "bundle.json")));
  assert.deepEqual(compliance.files(join(input.root, "dist/compliance")).filter((path) => path.startsWith("prepare-")), []);
  const rejected = await prepareCompliance({ ...input, run, fetchSource: async () => Promise.reject(new Error("network")) });
  assert.equal(rejected._tag, "CompliancePreparationFailed");
  mkdirSync(join(input.root, "dist/compliance/downloads"), { recursive: true });
  copyFileSync(join(root, "dist/compliance/downloads/rescript.tar.gz"), join(input.root, "dist/compliance/downloads/rescript.tar.gz"));
  const tarFailed = await prepareCompliance({ ...input, run: (program, args) => program === "tar" ? failure : run(program, args) });
  assert.deepEqual(tarFailed, failure);
});

test("CLI prepares a real isolated bundle and reports failure with exit 2", (context) => {
  const input = fixture(context);
  symlinkSync(join(root, "vendor/rescript"), join(input.root, "vendor/rescript"));
  cpSync(join(root, "dist/compliance/downloads"), join(input.root, "dist/compliance/downloads"), { recursive: true });
  const script = join(root, "scripts/npm/compliance-cli.mjs");
  const env = { ...process.env, OPAMSWITCH: root };
  const prepared = spawnSync(process.execPath, [script, input.root], { env, encoding: "utf8" });
  assert.equal(prepared.status, 0, prepared.stderr);
  assert.match(prepared.stdout, /bundle prepared/);
  assert.equal(compliance.validateBundle(input.root, input.binary, input.bundle), undefined);
  const failed = spawnSync(process.execPath, [script, join(input.root, "missing")], { env, encoding: "utf8" });
  assert.equal(failed.status, 2);
  assert.match(failed.stderr, /opam/);
  const defaultRoot = spawnSync(process.execPath, [script], { env: { ...env, PATH: "" }, encoding: "utf8" });
  assert.equal(defaultRoot.status, 2);
  assert.match(defaultRoot.stderr, /opam/);
});
