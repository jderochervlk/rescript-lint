"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");
const { EventEmitter, once } = require("node:events");
const { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } = require("node:fs");
const { tmpdir } = require("node:os");
const { join, resolve } = require("node:path");
const { spawn, spawnSync } = require("node:child_process");
const targets = require("../../npm/targets.json");
const manifest = require("../../npm/package.json");
const { packageName, selectTarget } = require("../../npm/lib/platform.cjs");
const { detectHost, resolveBinary, runBinary, launch, finish } = require("../../npm/lib/launcher.cjs");
const { manifests, checkVersion, stagePackages } = require("../../scripts/npm/package.cjs");

const root = resolve(__dirname, "../..");
const nativeBinary = join(root, "_build/default/bin/main.exe");

function temporary(context) {
  const directory = mkdtempSync(join(tmpdir(), "rescript lint test "));
  context.after(() => rmSync(directory, { recursive: true, force: true }));
  return directory;
}

function hostTarget() {
  const detected = detectHost(process);
  assert.equal(detected._tag, "Host");
  const selected = selectTarget(detected.host);
  assert.equal(selected._tag, "Target");
  return selected.target;
}

function nativePackage(context, value = undefined) {
  const directory = temporary(context);
  const target = hostTarget();
  const packageDirectory = join(directory, packageName(target));
  mkdirSync(join(packageDirectory, "bin"), { recursive: true });
  const metadata = value === undefined ? { name: packageName(target), version: manifest.version } : value;
  writeFileSync(join(packageDirectory, "package.json"), JSON.stringify(metadata));
  return { directory, packageDirectory, target };
}

for (const target of targets) {
  test(`selects and packages ${target.id}`, () => {
    assert.deepEqual(selectTarget({ os: target.os, cpu: target.cpu, libc: target.libc }), { _tag: "Target", target });
    const metadata = manifests(target);
    assert.equal(metadata.native.name, `@jvlk/rescript-lint-${target.id}`);
    assert.deepEqual(metadata.native.os, [target.os]);
    assert.deepEqual(metadata.native.cpu, [target.cpu]);
    assert.deepEqual(metadata.native.libc, target.libc ? [target.libc] : undefined);
    assert.equal(metadata.main.private, true);
    assert.equal(metadata.native.private, true);
    assert.deepEqual(metadata.main.publishConfig, { access: "public", tag: "beta" });
    assert.deepEqual(metadata.native.publishConfig, { access: "public", tag: "beta" });
    assert.equal(metadata.main.license, "MIT");
    assert.equal(metadata.native.license, "SEE LICENSE IN DISTRIBUTION.md");
    assert.deepEqual(metadata.main.optionalDependencies,
      Object.fromEntries(targets.map((item) => [packageName(item), manifest.version])));
  });
}

test("rejects unsupported architectures and libc instead of guessing", () => {
  for (const host of [
    { os: "linux", cpu: "x64", libc: "musl" },
    { os: "linux", cpu: "x64" },
    { os: "win32", cpu: "x64" },
    { os: "win32", cpu: "arm64" },
    { os: "freebsd", cpu: "x64" },
  ]) assert.equal(selectTarget(host)._tag, "UnsupportedPlatform");
});

test("defers Windows from release packages and reports its status", () => {
  assert.deepEqual(targets.map((target) => target.id),
    ["linux-x64-gnu", "linux-arm64-gnu", "darwin-x64", "darwin-arm64"]);
  const windows = selectTarget({ os: "win32", cpu: "x64" });
  assert.equal(windows._tag, "UnsupportedPlatform");
  assert.match(windows.message, /Windows is deferred/);
  assert.equal(Object.hasOwn(manifests(hostTarget()).main.optionalDependencies,
    "@jvlk/rescript-lint-win32-x64"), false);
});

test("detects glibc, musl, non-Linux hosts and report failures", () => {
  const runtime = (header) => ({ platform: "linux", arch: "arm64", report: { getReport: () => ({ header }) } });
  assert.equal(detectHost(runtime({ glibcVersionRuntime: "2.35" })).host.libc, "glibc");
  assert.equal(detectHost(runtime({})).host.libc, "musl");
  assert.deepEqual(detectHost({ platform: "darwin", arch: "x64" }),
    { _tag: "Host", host: { os: "darwin", cpu: "x64", libc: undefined } });
  assert.equal(detectHost({ platform: "linux" })._tag, "PlatformDetectionFailed");
});

test("resolves matching native packages", (context) => {
  const { target, packageDirectory } = nativePackage(context);
  assert.deepEqual(resolveBinary(target, (specifier) => {
    assert.equal(specifier, `${packageName(target)}/package.json`);
    return join(packageDirectory, "package.json");
  }), { _tag: "Binary", path: join(packageDirectory, "bin", target.binary) });
});

for (const value of [null, {}, { name: "wrong", version: manifest.version }, { name: packageName(targets[0]), version: "9.0.0" }]) {
  test(`rejects invalid installed metadata: ${JSON.stringify(value)}`, (context) => {
    const { target, packageDirectory } = nativePackage(context, value);
    assert.equal(resolveBinary(target, () => join(packageDirectory, "package.json"))._tag, "PackageMismatch");
  });
}

test("handles missing and malformed package manifests", (context) => {
  const path = join(temporary(context), "package.json");
  assert.equal(resolveBinary(hostTarget(), () => path)._tag, "PackageUnavailable");
  writeFileSync(path, "not JSON");
  assert.equal(resolveBinary(hostTarget(), () => path)._tag, "PackageUnavailable");
});

test("preserves arguments, stdio and exit codes and removes signal handlers", async () => {
  const signals = new EventEmitter();
  const child = new EventEmitter();
  const result = runBinary("native path", ["--", "space ; & file.res"], signals, (path, args, options) => {
    assert.equal(path, "native path");
    assert.deepEqual(args, ["--", "space ; & file.res"]);
    assert.deepEqual(options, { stdio: "inherit", shell: false });
    return child;
  });
  child.emit("exit", 1, null);
  assert.deepEqual(await result, { _tag: "Exit", code: 1 });
  assert.equal(signals.listenerCount("SIGINT"), 0);
  assert.equal(signals.listenerCount("SIGTERM"), 0);
});

test("forwards signals and preserves signal termination", async () => {
  const signals = new EventEmitter();
  const child = new EventEmitter();
  const received = [];
  child.kill = (signal) => received.push(signal);
  const result = runBinary("native", [], signals, () => child);
  signals.emit("SIGINT");
  signals.emit("SIGTERM");
  assert.deepEqual(received, ["SIGINT", "SIGTERM"]);
  child.emit("exit", null, "SIGTERM");
  assert.deepEqual(await result, { _tag: "Signal", signal: "SIGTERM" });
  assert.equal(signals.listenerCount("SIGTERM"), 0);
});

test("reports both asynchronous spawn failures and invalid spawn arguments", async (context) => {
  const signals = new EventEmitter();
  assert.equal((await runBinary(join(temporary(context), "missing"), [], signals))._tag, "LaunchFailed");
  assert.equal(signals.listenerCount("SIGINT"), 0);
  assert.equal((await runBinary("\0", []))._tag, "LaunchFailed");
  const child = new EventEmitter();
  const result = runBinary("native", [], signals, () => child);
  child.emit("exit", null, null);
  assert.deepEqual(await result, { _tag: "Exit", code: 2 });
});

test("launch returns platform errors", async () => {
  assert.equal((await launch({ platform: "linux" }))._tag, "PlatformDetectionFailed");
  assert.equal((await launch({ platform: "unsupported", arch: "x64" }))._tag, "UnsupportedPlatform");
});

test("finish re-raises native termination signals at the process boundary", () => {
  const calls = [];
  finish({ _tag: "Signal", signal: "SIGTERM" }, { signal: (signal) => calls.push(signal) });
  assert.deepEqual(calls, ["SIGTERM"]);
});

test("CLI reports missing optional dependencies with exit 2", () => {
  const result = spawnSync(process.execPath, [join(root, "npm/bin/rescript-lint.cjs"), "--version"],
    { encoding: "utf8", env: { ...process.env, NODE_PATH: "" } });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /optional dependencies/);
});

test("CLI preserves output, arguments and exit status with an installed native package", (context) => {
  const { directory, target, packageDirectory } = nativePackage(context);
  copyFileSync(process.execPath, join(packageDirectory, "bin", target.binary));
  const script = 'process.stdout.write(JSON.stringify({args: process.argv.slice(1), input: require("node:fs").readFileSync(0, "utf8")})); process.stderr.write("diagnostic"); process.exitCode = 7;';
  const args = ["a file.res", "semi;colon", "--", "a&b"];
  const result = spawnSync(process.execPath, [join(root, "npm/bin/rescript-lint.cjs"), "-e", script, "--", ...args],
    { encoding: "utf8", input: "stdin content", env: { ...process.env, NODE_PATH: directory } });
  assert.equal(result.status, 7, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), { args, input: "stdin content" });
  assert.equal(result.stderr, "diagnostic");
});

test("CLI forwards a directly received POSIX signal to the native child", {
  skip: process.platform === "win32", timeout: 10000,
}, async (context) => {
  const { directory, target, packageDirectory } = nativePackage(context);
  copyFileSync(process.execPath, join(packageDirectory, "bin", target.binary));
  const child = spawn(process.execPath, [join(root, "npm/bin/rescript-lint.cjs"), "-e",
    'process.stdout.write("ready"); setInterval(() => {}, 1000);'],
  { env: { ...process.env, NODE_PATH: directory }, stdio: ["ignore", "pipe", "pipe"] });
  context.after(() => child.kill("SIGKILL"));
  const exited = once(child, "exit");
  const [ready] = await once(child.stdout, "data");
  assert.equal(ready.toString(), "ready");
  child.kill("SIGTERM");
  assert.deepEqual(await exited, [null, "SIGTERM"]);
});

test("version check refuses unavailable or mismatched binaries", () => {
  assert.equal(checkVersion("binary", () => ({ error: new Error("ENOENT"), status: null }))._tag, "BinaryUnavailable");
  assert.equal(checkVersion("binary", () => ({ status: 2 }))._tag, "BinaryUnavailable");
  assert.equal(checkVersion("binary", () => ({ status: 0, stdout: "9.0.0\n" }))._tag, "VersionMismatch");
  assert.deepEqual(checkVersion("binary", () => ({ status: 0, stdout: `${manifest.version}\r\n` })), { _tag: "VersionChecked" });
});

test("stages a real release binary with synchronized manifests", (context) => {
  const target = hostTarget();
  const result = stagePackages({ root, destination: temporary(context), binary: nativeBinary, target });
  assert.equal(result._tag, "Staged", result.message);
  assert.deepEqual(JSON.parse(readFileSync(join(result.main, "package.json"), "utf8")), manifests(target).main);
  assert.deepEqual(JSON.parse(readFileSync(join(result.native, "package.json"), "utf8")), manifests(target).native);
  const readme = readFileSync(join(root, "npm", "README.md"), "utf8");
  for (const directory of [result.main, result.native]) {
    assert.equal(readFileSync(join(directory, "README.md"), "utf8"), readme);
  }
  assert.equal(spawnSync(join(result.native, "bin", target.binary), ["--version"], { encoding: "utf8" }).stdout.trim(), manifest.version);
});

test("staging returns version and filesystem errors", (context) => {
  const destination = temporary(context);
  const options = { root, destination, binary: join(destination, "missing"), target: hostTarget() };
  assert.equal(stagePackages(options)._tag, "BinaryUnavailable");
  assert.equal(stagePackages({ ...options, binary: process.execPath })._tag, "VersionMismatch");
  const file = join(destination, "not-a-directory");
  writeFileSync(file, "blocked");
  assert.equal(stagePackages({ ...options, destination: file, binary: nativeBinary })._tag, "StagingFailed");
});

test("pack CLI requires npm, validates binaries, and packs both packages", () => {
  const command = join(root, "scripts/npm/pack-cli.mjs");
  const run = (args, env = process.env) => spawnSync(process.execPath, [command, ...args], { encoding: "utf8", env });
  assert.match(run([], { ...process.env, npm_execpath: "" }).stderr, /npm run pack:native/);
  assert.match(run([process.execPath]).stderr, /versions differ/);
  assert.match(run([nativeBinary], { ...process.env, npm_execpath: "missing-npm.cjs" }).stderr, /npm pack failed/);
  const packed = run([]);
  assert.equal(packed.status, 0, packed.stderr);
});

test("pack returns platform detection, unsupported host and filesystem failures", async (context) => {
  const { packForHost } = await import("../../scripts/npm/pack.mjs");
  const runtime = { env: process.env, platform: "linux" };
  assert.equal(packForHost({ root, runtime })._tag, "PlatformDetectionFailed");
  assert.equal(packForHost({ root, runtime: { ...runtime, platform: "freebsd" } })._tag, "UnsupportedPlatform");
  const file = join(temporary(context), "not-a-directory");
  writeFileSync(file, "blocked");
  assert.equal(packForHost({ root: file, runtime: process })._tag, "PackagingFailed");
});
