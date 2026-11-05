import { selectPendingRelease } from "./alpha-release-selection.mjs";
import { owned } from "./reconcile.mjs";

export async function discoverPendingRelease(capabilities, { repository, cutoff, requestedVersion }) {
  const { api, head, ancestor, readCheckpoint, readCheckpointAt, readVersionAt, readLedger } = capabilities;
  const mainSha = (await api(`repos/${repository}/git/ref/heads/main`)).object.sha;
  if (head() !== mainSha) throw new Error("Selector must run from current trusted main");
  const checkpoint = readCheckpoint();
  if (!ancestor(checkpoint.baseline, mainSha)) throw new Error("Version checkpoint is not on trusted main");
  const pulls = await allPulls(api, repository);
  const eligible = [];
  for (const pr of pulls) {
    if (!checkpoint.automation.includes(pr.number)) continue;
    if (!owned(pr, { repository, bot: "github-actions[bot]" })) {
      throw new Error(`Registered version PR #${pr.number} has an identity mismatch`);
    }
    if (!pr.merged_at || !pr.merge_commit_sha || !ancestor(pr.merge_commit_sha, mainSha)) {
      throw new Error(`Registered version PR #${pr.number} is not merged on main`);
    }
    if (ancestor(pr.merge_commit_sha, checkpoint.baseline)) continue;
    const historical = readCheckpointAt(pr.merge_commit_sha);
    if (!historical.automation.includes(pr.number)) {
      throw new Error(`Version PR #${pr.number} was not registered at its merge`);
    }
    eligible.push({
      ...pr,
      repository,
      version: readVersionAt(pr.merge_commit_sha),
      onMain: true,
      afterCheckpoint: true,
    });
  }
  return selectPendingRelease({
    pullRequests: eligible,
    checkpoint,
    mainSha,
    cutoff,
    ledger: await readLedger(),
    repository,
    requestedVersion,
  });
}

async function allPulls(api, repository) {
  const pulls = [];
  for (let page = 1; ; page++) {
    const batch = await api(`repos/${repository}/pulls?state=all&per_page=100&page=${page}`);
    pulls.push(...batch);
    if (batch.length < 100) return pulls;
  }
}
