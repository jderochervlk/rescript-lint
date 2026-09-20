"use strict";

const { dirname, join } = require("node:path");
const { readFileSync } = require("node:fs");
const { spawn } = require("node:child_process");
const manifest = require("../package.json");
const { packageName, selectTarget } = require("./platform.cjs");

function detectHost(runtime) {
  try {
    const libc = runtime.platform === "linux"
      ? (runtime.report.getReport().header.glibcVersionRuntime ? "glibc" : "musl")
      : undefined;
    return { _tag: "Host", host: { os: runtime.platform, cpu: runtime.arch, libc } };
  } catch {
    return { _tag: "PlatformDetectionFailed", message: "Unable to detect the system C library." };
  }
}

function resolveBinary(target, resolve = require.resolve) {
  const name = packageName(target);
  try {
    const path = resolve(`${name}/package.json`);
    const installed = JSON.parse(readFileSync(path, "utf8"));
    if (installed?.name !== name || installed?.version !== manifest.version) {
      return { _tag: "PackageMismatch", message: `Expected ${name}@${manifest.version}. Reinstall @jvlk/rescript-lint.` };
    }
    return { _tag: "Binary", path: join(dirname(path), "bin", target.binary) };
  } catch {
    return { _tag: "PackageUnavailable", message:
      `Cannot load ${name}@${manifest.version}. Reinstall with optional dependencies enabled (do not use --omit=optional).` };
  }
}

// Keep the wrapper alive to forward signals sent directly to its PID, too.
function waitForChild(child, signals) {
  return new Promise((resolve) => {
    const handlers = ["SIGINT", "SIGTERM"].map((signal) => {
      const handler = () => child.kill(signal);
      signals.on(signal, handler);
      return { signal, handler };
    });
    const finish = (result) => {
      handlers.forEach(({ signal, handler }) => signals.removeListener(signal, handler));
      resolve(result);
    };
    child.once("error", () => finish({ _tag: "LaunchFailed", message: "Cannot execute the native linter. Check permissions and system runtime libraries." }));
    child.once("exit", (code, signal) => finish(signal
      ? { _tag: "Signal", signal }
      : { _tag: "Exit", code: code ?? 2 }));
  });
}

async function runBinary(path, args, signals = process, start = spawn) {
  try {
    return await waitForChild(start(path, args, { stdio: "inherit", shell: false }), signals);
  } catch {
    return { _tag: "LaunchFailed", message: "Unable to start the native linter process." };
  }
}

async function launch(runtime) {
  const detected = detectHost(runtime);
  if (detected._tag !== "Host") return detected;
  const selected = selectTarget(detected.host);
  if (selected._tag !== "Target") return selected;
  const binary = resolveBinary(selected.target);
  if (binary._tag !== "Binary") return binary;
  return runBinary(binary.path, runtime.argv.slice(2), runtime);
}

const terminal = {
  setExitCode: (code) => { process.exitCode = code; },
  signal: (signal) => process.kill(process.pid, signal),
  writeError: (message) => process.stderr.write(message),
};

function finish(result, output = terminal) {
  if (result._tag === "Exit") {
    output.setExitCode(result.code);
  } else if (result._tag === "Signal") {
    output.signal(result.signal);
  } else {
    output.writeError(`rescript-lint: ${result.message}\n`);
    output.setExitCode(2);
  }
}

module.exports = { detectHost, resolveBinary, runBinary, launch, finish };
