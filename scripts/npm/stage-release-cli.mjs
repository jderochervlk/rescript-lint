import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import targets from "../../npm/targets.json" with { type: "json" };
import manifest from "../../npm/package.json" with { type: "json" };
import { releasePackages, stageRelease } from "./stage-release.mjs";

function stage(entry) {
  if (!process.env.npm_execpath) return { _tag: "StagingFailed", message: "Run npm run stage:release." };
  const result = spawnSync(process.execPath, [process.env.npm_execpath,
    "stage", "publish", entry.tarball, "--access", "public", "--tag", "alpha", "--ignore-scripts"],
  { stdio: "inherit", timeout: 120_000 });
  return result.status === 0
    ? { _tag: "PackageStaged" }
    : { _tag: "StagingFailed", message: `Staging failed for ${entry.name}. Inspect npm stage list before retrying.` };
}

const artifacts = fileURLToPath(new URL("../../artifacts/", import.meta.url));
const result = await stageRelease({
  packages: releasePackages({ targets, manifest, artifacts }), env: process.env,
  request: fetch, exists: existsSync, stage,
});
if (result._tag === "ReleaseStaged") {
  process.stdout.write("All six packages are staged. Review the stage IDs and approve native packages before the launcher with npm 2FA.\n");
} else {
  process.stderr.write(`${result.message}\n`);
  process.exitCode = 2;
}
