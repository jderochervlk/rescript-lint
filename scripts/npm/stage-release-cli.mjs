import { spawnSync } from "node:child_process";
import { appendFileSync, existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { stageRelease } from "./stage-release.mjs";
import { readVersions, sourceReleaseGuard } from "../version/version.mjs";
import { validateTargetEvidence } from "./alpha-staging-artifacts.mjs";
import { beginAttempt, finishAttempt, recordAccepted, requireInspection } from "./alpha-staging-ledger.mjs";
import { commitLedger, readLedger } from "./alpha-staging-github-ledger.mjs";
import { createApi } from "../version/github-api.mjs";
import { createNpmStageAdapter } from "./stage-release-npm.mjs";
import { releaseSummary } from "./alpha-staging-summary.mjs";

// Also guard direct/manual staging invocations before requesting OIDC or uploads.
const checkoutRoot = fileURLToPath(new URL("../../", import.meta.url));
const sourceRoot = process.env.RELEASE_SOURCE_DIR ?? checkoutRoot;
const releaseVersions = readVersions(sourceRoot);
const sourceManifest = JSON.parse(readFileSync(join(sourceRoot, "npm/package.json"), "utf8"));
const targets = JSON.parse(readFileSync(join(sourceRoot, "npm/targets.json"), "utf8"));
if (process.env.RELEASE_SOURCE_SHA) {
  const sourceHead = spawnSync("git", ["rev-parse", "HEAD"], { cwd: sourceRoot, encoding: "utf8" });
  if (sourceHead.status !== 0 || sourceHead.stdout.trim() !== process.env.RELEASE_SOURCE_SHA) {
    throw new Error("Checked out source does not match selected release SHA");
  }
}
if (process.env.RELEASE_VERSION && sourceManifest.version !== process.env.RELEASE_VERSION) {
  throw new Error("Selected release source does not match RELEASE_VERSION");
}
sourceReleaseGuard(releaseVersions, {
  refType: process.env.GITHUB_REF_TYPE, refName: process.env.GITHUB_REF_NAME,
});

const artifacts = fileURLToPath(new URL("../../artifacts/", import.meta.url));
const manifest = {
  ...sourceManifest,
  version: process.env.RELEASE_VERSION ?? sourceManifest.version,
};
const stagingEnabled = process.env.RELEASE_STAGE === "true";
if (!stagingEnabled) {
  throw new Error("Release staging requires RELEASE_STAGE=true from an authorized staging job");
}
const ledgerContext = createLedgerContext();
const stage = createNpmStageAdapter({
  execPath: process.execPath,
  npmExecPath: process.env.npm_execpath,
  version: manifest.version,
});
const targetEvidence = targets.map(target => {
  const evidencePath = join(artifacts, `packages-${target.id}`, "release-evidence.json");
  const evidence = JSON.parse(readFileSync(evidencePath, "utf8"));
  return validateTargetEvidence({
    evidence,
    expected: {
      sourceSha: process.env.RELEASE_SOURCE_SHA,
      runId: process.env.RELEASE_RUN_ID,
      version: manifest.version,
      targetId: target.id,
    },
    targets, manifest: sourceManifest, artifacts,
  });
});
const packages = [
  ...targetEvidence.map(entries => entries[0]),
  targetEvidence[0][1],
];
const result = await stageRelease({
  packages, env: process.env,
  request: fetch, exists: existsSync, stage,
  beginAttempt: ledgerContext.beginAttempt,
  onAccepted: ledgerContext.onAccepted,
  completeAttempt: ledgerContext.completeAttempt,
  inspectAttempt: ledgerContext.inspectAttempt,
});
const releaseRecord = ledgerContext.releaseRecord();
const summary = releaseSummary({
  result, releaseRecord, packages, env: process.env,
  sourceSha: process.env.RELEASE_SOURCE_SHA,
  version: manifest.version,
  pullRequest: Number(process.env.RELEASE_PULL_REQUEST),
  runId: process.env.RELEASE_RUN_ID,
});
process.stdout.write(`${summary}\n`);
if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${summary}\n`);
if (result._tag !== "ReleaseStaged" && result._tag !== "AlreadyStaged") process.exitCode = 2;

function createLedgerContext() {
  const repository = process.env.GITHUB_REPOSITORY;
  const sha = process.env.RELEASE_SOURCE_SHA;
  const runId = process.env.RELEASE_RUN_ID;
  const cutoff = Number(process.env.RELEASE_CUTOFF);
  const pullRequest = Number(process.env.RELEASE_PULL_REQUEST);
  const ref = process.env.GITHUB_REF;
  const event = process.env.GITHUB_EVENT_NAME;
  const trustedMainEvents = new Set([
    "schedule:refs/heads/main",
    "push:refs/heads/main",
    "workflow_dispatch:refs/heads/main",
  ]);
  const isTrustedTag = event === "push" && process.env.GITHUB_REF_TYPE === "tag" &&
    /^refs\/tags\/v0\.1\.0-alpha\.[1-9]\d+$/.test(ref ?? "");
  const trustedEvent = repository === "jderochervlk/rescript-lint" &&
    (trustedMainEvents.has(`${event}:${ref}`) || isTrustedTag);
  if (process.env.GITHUB_ACTIONS !== "true") {
    throw new Error("Staging requires trusted release source and run identity");
  }
  if (!trustedEvent) throw new Error("Staging requires trusted release source and run identity");
  if (process.env.GITHUB_WORKFLOW_REF !== `jderochervlk/rescript-lint/.github/workflows/release.yml@${ref}`) {
    throw new Error("Staging requires trusted release source and run identity");
  }
  if (!process.env.GH_TOKEN) throw new Error("Staging requires trusted release source and run identity");
  if (!/^[a-f0-9]{40}$/.test(sha ?? "")) throw new Error("Staging requires trusted release source and run identity");
  if (!runId) throw new Error("Staging requires trusted release source and run identity");
  if (!Number.isSafeInteger(pullRequest)) throw new Error("Staging requires trusted release source and run identity");
  if (pullRequest < 1) throw new Error("Staging requires trusted release source and run identity");
  const api = createApi((command, args, options) => {
    const result = spawnSync(command, args, { ...options, encoding: "utf8" });
    if (result.status !== 0) throw new Error(result.stderr);
    return result.stdout;
  }, process.env);
  const candidate = { version: manifest.version, sourceSha: sha, pullRequest,
    originalRun: Number(runId), runId, attemptId: `${runId}-${sha}`, packages: [] };
  let observed;
  return {
    beginAttempt: async packages => {
      observed = await readLedger(api, repository);
      if (observed.ledger.cutoff !== `0.1.0-alpha.${cutoff}`) {
        throw new Error("Staging cutoff differs from the reviewed ledger cutoff");
      }
      const prepared = beginAttempt(observed.ledger, {
        ...candidate,
        packages: packages.map(entry => ({ name: entry.name, artifact: entry.tarball, digest: entry.digest })),
      });
      if (prepared._tag === "AlreadyStaged") return prepared;
      observed = await commitLedger({ api, repository, observed, next: prepared.ledger,
        message: `chore(release): claim ${manifest.version} staging attempt ${runId}` });
      const confirmed = await readLedger(api, repository);
      const current = confirmed.ledger.releases.find(item => item.version === manifest.version);
      if (confirmed.tip !== observed.tip || current?.attemptId !== candidate.attemptId ||
          current?.sourceSha !== sha || current.pullRequest !== pullRequest ||
          current.runId !== runId || current.originalRun !== Number(runId) ||
          current.status !== "Attempting" || current.accepted.length !== 0 ||
          current.packages.some((item, index) =>
            item.digest !== packages[index]?.digest ||
            item.artifact !== packages[index]?.tarball)) {
        throw new Error("Committed staging attempt did not reread exactly");
      }
    },
    onAccepted: async (entry, stageId) => {
      const fresh = await readLedger(api, repository);
      observed = await commitLedger({ api, repository, observed: fresh,
        next: recordAccepted(fresh.ledger, manifest.version, entry.name, stageId),
        message: `chore(release): record ${entry.name} staging acceptance` });
    },
    completeAttempt: async () => {
      const fresh = await readLedger(api, repository);
      observed = await commitLedger({ api, repository, observed: fresh,
        next: finishAttempt(fresh.ledger, manifest.version),
        message: `chore(release): complete ${manifest.version} staging` });
    },
    inspectAttempt: async reason => {
      const fresh = await readLedger(api, repository);
      observed = await commitLedger({ api, repository, observed: fresh,
        next: requireInspection(fresh.ledger, manifest.version, reason),
        message: `chore(release): flag ${manifest.version} for inspection` });
    },
    releaseRecord: () => observed?.ledger.releases.find(item => item.version === manifest.version),
  };
}
