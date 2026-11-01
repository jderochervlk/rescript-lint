// Only run from trusted main in GitHub Actions with GITHUB_TOKEN, never a PR checkout.
import { execFileSync, spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { setTimeout as pause } from "node:timers/promises";
import { readVersions, generateOpam } from "./version.mjs";
import { createApi } from "./github-api.mjs";
import { statePath } from "./reconcile.mjs";
import { run } from "./reconcile-run.mjs";

function command(program, args, options = {}) {
  return execFileSync(program, args, { encoding: "utf8", ...options }).trim();
}

function ancestor(older, newer) {
  const result = spawnSync("git", ["merge-base", "--is-ancestor", older, newer]);
  if (result.status !== 0 && result.status !== 1) throw new Error("Cannot establish merge ancestry; fetch full main history");
  return result.status === 0;
}

try {
  await run({ api: createApi(command, process.env), pause,
    head: () => command("git", ["rev-parse", "HEAD"]), ancestor,
    readVersions, readCheckpoint: () => JSON.parse(readFileSync(statePath, "utf8")),
    generateOpam, env: process.env, log: console.log });
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
