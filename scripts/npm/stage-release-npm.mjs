import { spawnSync } from "node:child_process";

export function createNpmStageAdapter({ execPath, npmExecPath, version, run = spawnSync }) {
  return async entry => {
    if (!npmExecPath) {
      return { _tag: "StagingFailed", message: "Run npm run stage:release with npm 11.15.0 or newer." };
    }
    const result = run(execPath, [
      npmExecPath, "stage", "publish", entry.tarball, "--json", "--access", "public",
      "--tag", "alpha", "--ignore-scripts",
    ], { encoding: "utf8", timeout: 120_000 });
    if (result.error || result.status !== 0) {
      return {
        _tag: "StagingFailed",
        message: `Staging failed or timed out for ${entry.name}; inspect npm stage list before retrying.`,
      };
    }
    try {
      const output = JSON.parse(result.stdout);
      const evidence = output?.[entry.name];
      if (evidence?.name === entry.name && evidence.version === version &&
          evidence.integrity === entry.digest &&
          typeof evidence.stageId === "string" && evidence.stageId) {
        return { _tag: "PackageStaged", stageId: evidence.stageId };
      }
    } catch {
      // A successful command without matching machine-readable evidence is ambiguous.
    }
    return {
      _tag: "StageOutcomeUnknown",
      message: `npm returned success without verified stage identity for ${entry.name}; inspect before retrying.`,
    };
  };
}
