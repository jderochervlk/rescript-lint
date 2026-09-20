"use strict";

const { chmodSync, copyFileSync, cpSync, mkdirSync, writeFileSync } = require("node:fs");
const { join } = require("node:path");
const { spawnSync } = require("node:child_process");
const manifest = require("../../npm/package.json");
const targets = require("../../npm/targets.json");
const { packageName } = require("../../npm/lib/platform.cjs");

function manifests(target) {
  const optionalDependencies = Object.fromEntries(targets.map((item) => [packageName(item), manifest.version]));
  return {
    main: { ...manifest, optionalDependencies },
    native: {
      name: packageName(target), version: manifest.version,
      description: `Native binary for ${manifest.name} (${target.id})`,
      private: true, license: "SEE LICENSE IN DISTRIBUTION.md", repository: manifest.repository,
      os: [target.os], cpu: [target.cpu],
      ...(target.libc ? { libc: [target.libc] } : {}),
      files: ["bin/", "README.md", "LICENSE", "DISTRIBUTION.md"],
      publishConfig: manifest.publishConfig,
    },
  };
}

function checkVersion(binary, execute = spawnSync) {
  const result = execute(binary, ["--version"], { encoding: "utf8" });
  if (result.error || result.status !== 0) {
    return { _tag: "BinaryUnavailable", message: `Cannot run ${binary} --version.` };
  }
  return result.stdout.trim() === manifest.version
    ? { _tag: "VersionChecked" }
    : { _tag: "VersionMismatch", message: `Binary and npm versions differ; expected ${manifest.version}, got ${result.stdout.trim()}.` };
}

function writeManifest(directory, value) {
  writeFileSync(join(directory, "package.json"), `${JSON.stringify(value, null, 2)}\n`);
}

function writePackages({ root, destination, binary, target }) {
  const main = join(destination, "main");
  const native = join(destination, target.id);
  const metadata = manifests(target);
  mkdirSync(join(native, "bin"), { recursive: true });
  cpSync(join(root, "npm"), main, { recursive: true });
  copyFileSync(binary, join(native, "bin", target.binary));
  chmodSync(join(native, "bin", target.binary), 0o755);
  chmodSync(join(main, "bin", "rescript-lint.cjs"), 0o755);
  for (const directory of [main, native]) {
    copyFileSync(join(root, "README.md"), join(directory, "README.md"));
    copyFileSync(join(root, "LICENSE"), join(directory, "LICENSE"));
    copyFileSync(join(root, "docs", "DISTRIBUTION.md"), join(directory, "DISTRIBUTION.md"));
  }
  writeManifest(main, metadata.main);
  writeManifest(native, metadata.native);
  return { _tag: "Staged", main, native };
}

function stagePackages(options) {
  try {
    const checked = checkVersion(options.binary);
    if (checked._tag !== "VersionChecked") return checked;
    return writePackages(options);
  } catch (error) {
    return { _tag: "StagingFailed", message: `Cannot stage packages: ${String(error)}` };
  }
}

module.exports = { manifests, checkVersion, stagePackages };
