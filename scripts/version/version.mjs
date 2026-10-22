import { readFileSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

export const paths = ["npm/package.json", "dune-project", "lib/cli/cli_command.ml",
  "test/integration/cli.t", "rescript_linter.opam"];

export function alpha(version) {
  const match = /^0\.1\.0-alpha\.(0|[1-9][0-9]*)$/.exec(version);
  if (!match || match[0] !== version || !Number.isSafeInteger(Number(match[1]))) {
    throw new Error(`Unsupported version: ${version}; expected 0.1.0-alpha.N`);
  }
  return Number(match[1]);
}

function replaceOne(text, pattern, version, next, label) {
  const matches = [...text.matchAll(pattern)];
  if (matches.length !== 1 || matches[0][2] !== version) {
    throw new Error(`Version drift or unexpected pattern: ${label}`);
  }
  return text.replace(pattern, (_, before, _version, after) => before + next + after);
}

export function plan(files, count = 0) {
  const manifest = JSON.parse(files["npm/package.json"]);
  const current = manifest.version;
  const counter = alpha(current);
  if (manifest.publishConfig?.tag !== "alpha") throw new Error("publishConfig.tag must be alpha");
  if (!Number.isSafeInteger(count) || count < 0 || !Number.isSafeInteger(counter + count)) {
    throw new Error("Merge count must be a nonnegative safe integer without version overflow");
  }
  const next = `0.1.0-alpha.${counter + count}`;
  const updated = { ...files };
  updated["npm/package.json"] = replaceOne(files["npm/package.json"],
    /(^[ \t]*"version": ")([^"\n]+)(",?$)/gm, current, next, "npm/package.json");
  const specs = [
    ["dune-project", /^(\(version )([^\s)]+)(\))$/gm],
    ["lib/cli/cli_command.ml", /^(let version = ")([^"\n]+)(")$/gm],
    ["rescript_linter.opam", /^(version: ")([^"\n]+)(")$/gm],
  ];
  for (const [path, pattern] of specs) {
    updated[path] = replaceOne(files[path], pattern, current, next, path);
  }
  let transcript = replaceOne(files["test/integration/cli.t"],
    /^(  \$ rescript-lint --version\n  )([^\n]+)()$/gm, current, next, "CLI expectation");
  transcript = replaceOne(transcript,
    /^(  "serverInfo":\{"name":"rescript-lint","version":")([^"\n]+)("\})$/gm,
    current, next, "LSP expectation");
  updated["test/integration/cli.t"] = transcript;
  return { current, next, count, files: updated, changed: count === 0 ? [] : paths };
}

export function readVersions(root) {
  return Object.fromEntries(paths.map(path => [path, readFileSync(join(root, path), "utf8").replace(/\r\n/g, "\n")]));
}

// Generate metadata in an isolated project before writing any real source.
// Dune, not this script, remains the owner of generated Opam metadata.
export function generateOpam(root, files) {
  const temporary = mkdtempSync(join(root, ".version-generation-"));
  try {
    writeFileSync(join(temporary, "dune-project"), files["dune-project"]);
    writeFileSync(join(temporary, "rescript_linter.opam.template"),
      readFileSync(join(root, "rescript_linter.opam.template"), "utf8"));
    const result = spawnSync("opam", ["exec", "--", "dune", "build", "--root", temporary,
      "rescript_linter.opam"], { cwd: root, encoding: "utf8" });
    if (result.status !== 0) throw new Error(`Dune metadata generation failed: ${result.error ?? result.stderr}`);
    const generated = readFileSync(join(temporary, "_build/default/rescript_linter.opam"), "utf8");
    if (generated !== files["rescript_linter.opam"]) {
      throw new Error("Dune generated unexpected metadata; reconcile metadata drift first");
    }
    return generated;
  } finally {
    rmSync(temporary, { recursive: true, force: true });
  }
}

export function update(root, count, { dryRun = false, generate = generateOpam } = {}) {
  const original = readVersions(root);
  const result = plan(original, count);
  if (dryRun || count === 0) return result;
  const generated = generate(root, result.files);
  if (generated !== result.files["rescript_linter.opam"]) throw new Error("Unexpected generated metadata");
  const files = { ...result.files, "rescript_linter.opam": generated };
  try {
    for (const path of paths) writeFileSync(join(root, path), files[path]);
  } catch (error) {
    for (const path of paths) writeFileSync(join(root, path), original[path]);
    throw error;
  }
  return { ...result, files };
}

export function sourceReleaseGuard(files, { refType, refName }) {
  const result = plan(files);
  if (refType === "tag" && refName !== `v${result.current}`) throw new Error("Tag/source version mismatch");
  return result.current;
}

export function releaseGuard(files, { refType, refName, cliVersion }) {
  const version = sourceReleaseGuard(files, { refType, refName });
  if (cliVersion !== version) throw new Error("CLI/source version mismatch");
  return version;
}
