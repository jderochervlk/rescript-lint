import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { createApi } from "./github-api.mjs";
import { discoverPendingRelease } from "./alpha-release-discovery.mjs";
import { readLedger } from "../npm/alpha-staging-github-ledger.mjs";

const repository = process.env.GITHUB_REPOSITORY;
const cutoff = Number(process.env.ALPHA_STAGING_CUTOFF);
const event = process.env.GITHUB_EVENT_NAME;
const ref = process.env.GITHUB_REF;
const trustedWorkflow = "jderochervlk/rescript-lint/.github/workflows/release.yml";
const trustedEvent = repository === "jderochervlk/rescript-lint" &&
  ((event === "schedule" && ref === "refs/heads/main") ||
   (event === "push" && (ref === "refs/heads/main" ||
     (process.env.GITHUB_REF_TYPE === "tag" && /^refs\/tags\/v0\.1\.0-alpha\.[1-9]\d+$/.test(ref ?? "")))) ||
   (event === "workflow_dispatch" && ref === "refs/heads/main"));
if (process.env.GITHUB_ACTIONS !== "true" || !trustedEvent ||
    process.env.GITHUB_WORKFLOW_REF !== `${trustedWorkflow}@${ref}` ||
    !process.env.GH_TOKEN || !Number.isSafeInteger(cutoff) || cutoff < 1) {
  throw new Error("Selector requires trusted Actions context and reviewed cutoff");
}
const root = process.cwd();
const git = (...args) => {
  const result = spawnSync("git", args, { cwd: root, encoding: "utf8" });
  if (result.status !== 0) throw new Error(`git ${args.join(" ")} failed: ${result.stderr}`);
  return result.stdout.trim();
};
const readAt = (sha, path) => git("show", `${sha}:${path}`);
const api = createApi((command, args, options) => {
  const result = spawnSync(command, args, { ...options, encoding: "utf8" });
  if (result.status !== 0) throw new Error(result.stderr);
  return result.stdout;
}, process.env);
const checkpointPath = ".github/alpha-version-state.json";
const candidate = await discoverPendingRelease({
  api,
  head: () => git("rev-parse", "HEAD"),
  ancestor: (older, newer) => {
    const result = spawnSync("git", ["merge-base", "--is-ancestor", older, newer], { cwd: root });
    if (result.status === 1) return false;
    if (result.status !== 0) throw new Error("Unable to verify main ancestry");
    return true;
  },
  readCheckpoint: () => JSON.parse(readFileSync(`${root}/${checkpointPath}`, "utf8")),
  readCheckpointAt: sha => JSON.parse(readAt(sha, checkpointPath)),
  readVersionAt: sha => JSON.parse(readAt(sha, "npm/package.json")).version,
  readLedger: async () => (await readLedger(api, repository)).ledger,
}, {
  repository, cutoff,
  requestedVersion: process.env.GITHUB_REF_TYPE === "tag"
    ? process.env.GITHUB_REF_NAME.replace(/^v/, "") : undefined,
});
if (process.env.GITHUB_REF_TYPE === "tag") {
  if (candidate._tag === "NoCandidate") {
    throw new Error("Requested release tag is not a registered version");
  }
  if (candidate._tag === "Selected" &&
      process.env.GITHUB_REF_NAME !== `v${candidate.release.version}`) {
    throw new Error("Requested release tag does not identify the oldest pending registered version");
  }
  const tagCommit = git("rev-parse", `${ref}^{}`);
  if (tagCommit !== candidate.release.sourceSha) {
    throw new Error("Release tag does not point to its canonical registered merge SHA");
  }
}
const output = candidate._tag === "Selected" ? candidate.release : null;
if (process.env.GITHUB_OUTPUT) {
  const { appendFileSync } = await import("node:fs");
  appendFileSync(process.env.GITHUB_OUTPUT,
    `selected=${output ? "true" : "false"}\nsource-sha=${output?.sourceSha ?? ""}\nversion=${output?.version ?? ""}\npr=${output?.pullRequest ?? ""}\ncontrol-sha=${git("rev-parse", "HEAD")}\n`);
}
process.stdout.write(`${JSON.stringify(candidate)}\n`);
