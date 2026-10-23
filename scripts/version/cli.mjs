import { resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { update, readVersions, releaseGuard } from "./version.mjs";

try {
  const [mode, rawCount, ...extra] = process.argv.slice(2);
  if (extra.length || !["check", "dry-run", "update", "release"].includes(mode) ||
      (["check", "release"].includes(mode) ? rawCount !== undefined : !/^(0|[1-9][0-9]*)$/.test(rawCount ?? ""))) {
    throw new Error("Usage: node scripts/version/cli.mjs check|release|dry-run COUNT|update COUNT");
  }
  const root = resolve(".");
  if (mode === "release") {
    const cli = spawnSync("opam", ["exec", "--", "dune", "exec", "--profile", "release",
      "rescript-lint", "--", "--version"], { encoding: "utf8" });
    if (cli.status !== 0) throw new Error(`CLI version check failed: ${cli.error ?? cli.stderr}`);
    console.log(`Release guard: ${releaseGuard(readVersions(root), {
      refType: process.env.GITHUB_REF_TYPE, refName: process.env.GITHUB_REF_NAME,
      cliVersion: cli.stdout.trim(),
    })} (alpha only)`);
  } else {
    const result = update(root, mode === "check" ? 0 : Number(rawCount), { dryRun: mode !== "update" });
    console.log(JSON.stringify({ current: result.current, next: result.next,
      merges: result.count, changed: result.changed, mode }, null, 2));
  }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
