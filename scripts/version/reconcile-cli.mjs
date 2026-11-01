// Only run from trusted main in GitHub Actions with GITHUB_TOKEN, never a PR checkout.
import { execFileSync, spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { readVersions, generateOpam } from "./version.mjs";
import { statePath } from "./reconcile.mjs";
import { run } from "./reconcile-run.mjs";

function command(program, args, options = {}) {
  return execFileSync(program, args, { encoding: "utf8", ...options }).trim();
}

function api(path, method = "GET", data) {
  return JSON.parse(command("gh", ["api", path, "--method", method,
    ...(data === undefined ? [] : ["--input", "-"])],
  data === undefined ? {} : { input: JSON.stringify(data) }));
}

function ancestor(older, newer) {
  const result = spawnSync("git", ["merge-base", "--is-ancestor", older, newer]);
  if (result.status !== 0 && result.status !== 1) throw new Error("Cannot establish merge ancestry; fetch full main history");
  return result.status === 0;
}

try {
  run({ api, head: () => command("git", ["rev-parse", "HEAD"]), ancestor,
    readVersions, readCheckpoint: () => JSON.parse(readFileSync(statePath, "utf8")),
    generateOpam, env: process.env, log: console.log });
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
