import { validateLedger } from "../npm/alpha-staging-ledger.mjs";

const versionPattern = /^0\.1\.0-alpha\.([1-9]\d*)$/;
const shaPattern = /^[a-f0-9]{40}$/;

export function selectPendingRelease({ pullRequests, checkpoint, mainSha, cutoff, ledger, repository, requestedVersion }) {
  validateLedger(ledger);
  if (requestedVersion !== undefined && !versionPattern.test(requestedVersion)) {
    throw new Error("Requested version is not canonical");
  }
  if (!shaPattern.test(mainSha) || !shaPattern.test(checkpoint.baseline) ||
      !Number.isSafeInteger(cutoff) || cutoff < 1 || !Array.isArray(pullRequests) ||
      typeof repository !== "string" || !repository ||
      !Array.isArray(checkpoint.automation) || new Set(checkpoint.automation).size !== checkpoint.automation.length) {
    throw new Error("Invalid trusted release-selection context");
  }
  if (ledger.cutoff !== `0.1.0-alpha.${cutoff}`) {
    throw new Error("Release cutoff differs from the initialized staging ledger");
  }
  const registered = new Set(checkpoint.automation);
  const staged = new Map(ledger.releases.map(release => [release.version, release]));
  const candidates = [];
  const versions = new Map();
  const sources = new Map();
  const pullRequestsByVersion = new Map();
  for (const pr of pullRequests) {
    if (!registered.has(pr.number)) continue;
    if (pr.state !== "closed" || !pr.merged_at || pr.base?.ref !== "main" ||
        pr.base.repo?.full_name !== repository || pr.head?.ref !== "automation/alpha-version" ||
        pr.head.repo?.full_name !== repository || pr.user?.login !== "github-actions[bot]") {
      throw new Error(`Registered automation PR #${pr.number} has invalid identity`);
    }
    const match = versionPattern.exec(pr.version ?? "");
    if (!match || !shaPattern.test(pr.merge_commit_sha) || !pr.onMain ||
        !pr.afterCheckpoint || !Number.isSafeInteger(Number(match[1]))) {
      throw new Error(`Registered version PR #${pr.number} is not a canonical merged release`);
    }
    if (Number(match[1]) <= cutoff) continue;
    const prior = versions.get(pr.version);
    if (prior && (prior.sourceSha !== pr.merge_commit_sha || prior.pullRequest !== pr.number)) {
      throw new Error(`Conflicting source ownership for ${pr.version}`);
    }
    const sourceOwner = sources.get(pr.merge_commit_sha);
    const pullOwner = pullRequestsByVersion.get(pr.number);
    if (sourceOwner && sourceOwner !== pr.version || pullOwner && pullOwner !== pr.version) {
      throw new Error(`Conflicting source ownership for ${pr.version}`);
    }
    versions.set(pr.version, { sourceSha: pr.merge_commit_sha, pullRequest: pr.number });
    sources.set(pr.merge_commit_sha, pr.version);
    pullRequestsByVersion.set(pr.number, pr.version);
    const ledgerEntry = staged.get(pr.version);
    if (ledgerEntry && (ledgerEntry.sourceSha !== pr.merge_commit_sha ||
        ledgerEntry.pullRequest !== pr.number)) {
      throw new Error(`Ledger identity conflicts with registered ${pr.version}`);
    }
    if (ledgerEntry && ledgerEntry.status !== "Staged") {
      throw new Error(`Earlier release ${pr.version} requires maintainer inspection`);
    }
    if (!ledgerEntry) candidates.push({
        version: pr.version, pullRequest: pr.number, sourceSha: pr.merge_commit_sha,
        mergedAt: pr.merged_at, sequence: Number(match[1]),
      });
  }
  const ordered = candidates.sort((left, right) => left.sequence - right.sequence);
  if (requestedVersion) {
    const completed = staged.get(requestedVersion);
    if (completed) return { _tag: "AlreadyStaged", release: completed };
    const requested = ordered.find(candidate => candidate.version === requestedVersion);
    if (!requested) return { _tag: "NoCandidate" };
    if (ordered[0]?.version !== requestedVersion) {
      throw new Error(`Earlier unresolved release ${ordered[0].version} blocks ${requestedVersion}`);
    }
    return { _tag: "Selected", release: requested };
  }
  return ordered[0] ? { _tag: "Selected", release: ordered[0] } : { _tag: "NoCandidate" };
}
