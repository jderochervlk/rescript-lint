import { spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, cpSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import manifest from "../../npm/package.json" with { type: "json" };
import targets from "../../npm/targets.json" with { type: "json" };
import { packageName } from "../../npm/lib/platform.mjs";
import compliance from "./compliance.cjs";

export function manifests(target) {
  const optionalDependencies = Object.fromEntries(targets.map((item) => [packageName(item), manifest.version]));
  return {
    main: { ...manifest, optionalDependencies },
    native: {
      name: packageName(target), version: manifest.version,
      description: `Native binary for ${manifest.name} (${target.id})`,
      license: "SEE LICENSE IN DISTRIBUTION.md", repository: manifest.repository,
      os: [target.os], cpu: [target.cpu],
      ...(target.libc ? { libc: [target.libc] } : {}),
      files: ["bin/", "README.md", "LICENSE", "DISTRIBUTION.md", "third-party/"],
      publishConfig: manifest.publishConfig,
    },
  };
}

export function checkVersion(binary, execute = spawnSync) {
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
  chmodSync(join(main, "bin", "rescript-lint.mjs"), 0o755);
  for (const directory of [main, native]) {
    copyFileSync(join(root, "npm", "README.md"), join(directory, "README.md"));
    copyFileSync(join(root, "LICENSE"), join(directory, "LICENSE"));
    copyFileSync(join(root, "docs", "DISTRIBUTION.md"), join(directory, "DISTRIBUTION.md"));
  }
  writeManifest(main, metadata.main);
  writeManifest(native, metadata.native);
  const staged = compliance.stageCompliance({ root, binary, destination: join(native, "third-party") });
  if (staged._tag !== "ComplianceStaged") return staged;
  return { _tag: "Staged", main, native };
}

export function stagePackages(options) {
  try {
    const checked = checkVersion(options.binary);
    if (checked._tag !== "VersionChecked") return checked;
    return writePackages(options);
  } catch (error) {
    return { _tag: "StagingFailed", message: `Cannot stage packages: ${String(error)}` };
  }
}
