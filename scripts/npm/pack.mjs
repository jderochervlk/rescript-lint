import { mkdtempSync, mkdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { detectHost } from "../../npm/lib/launcher.mjs";
import { selectTarget } from "../../npm/lib/platform.mjs";
import { stagePackages } from "./package.mjs";

function pack(directory, destination, runtime) {
  const result = spawnSync(runtime.execPath, [runtime.env.npm_execpath,
    "pack", directory, "--ignore-scripts", "--pack-destination", destination], { stdio: "inherit" });
  return result.status === 0
    ? { _tag: "Packed" }
    : { _tag: "PackFailed", message: `npm pack failed for ${directory}.` };
}

function prepare(target, { root, runtime }) {
  const destination = join(root, "dist", "npm", target.id);
  mkdirSync(destination, { recursive: true });
  const staging = mkdtempSync(join(destination, "stage-"));
  const binary = resolve(root, runtime.argv[2] ?? "_build/default/bin/main.exe");
  const staged = stagePackages({ root, destination: staging, binary, target });
  if (staged._tag !== "Staged") return staged;
  const native = pack(staged.native, destination, runtime);
  return native._tag === "Packed" ? pack(staged.main, destination, runtime) : native;
}

export function packForHost({ root, runtime }) {
  if (!runtime.env.npm_execpath) {
    return { _tag: "MissingNpm", message: "Run npm run pack:native -- [binary-path]." };
  }
  try {
    const detected = detectHost(runtime);
    if (detected._tag !== "Host") return detected;
    const selected = selectTarget(detected.host);
    return selected._tag === "Target" ? prepare(selected.target, { root, runtime }) : selected;
  } catch (error) {
    return { _tag: "PackagingFailed", message: `Packaging failed: ${String(error)}` };
  }
}
