import assert from "node:assert/strict";
import test from "node:test";
import { discoverPendingRelease } from "../../scripts/version/alpha-release-discovery.mjs";

const repository = "jderochervlk/rescript-lint";
const baseline = "b".repeat(40);
const merge23 = "c".repeat(40);
const merge24 = "d".repeat(40);
const tip = "e".repeat(40);

function registeredPr(number, sha) {
  return {
    number, state: "closed", merged_at: "2026-11-02T10:00:00Z",
    merge_commit_sha: sha,
    user: { login: "github-actions[bot]" },
    head: { ref: "automation/alpha-version", repo: { full_name: repository } },
    base: { ref: "main", repo: { full_name: repository } },
  };
}

function capabilities({ mainSha = tip, pulls = [registeredPr(57, merge23), registeredPr(58, merge24)] } = {}) {
  const ancestry = new Set([
    `${baseline}:${mainSha}`,
    `${merge23}:${mainSha}`, `${merge24}:${mainSha}`,
  ]);
  return {
    api: async path => {
      if (path.endsWith("/git/ref/heads/main")) return { object: { sha: mainSha } };
      if (path.includes("/pulls?")) return pulls;
      throw new Error(`Unexpected fixture endpoint ${path}`);
    },
    head: () => mainSha,
    ancestor: (older, newer) => ancestry.has(`${older}:${newer}`),
    readCheckpoint: () => ({ baseline, automation: [57, 58] }),
    readCheckpointAt: () => ({ baseline, automation: [57, 58] }),
    readVersionAt: sha => sha === merge23 ? "0.1.0-alpha.23" : "0.1.0-alpha.24",
    readLedger: async () => ({ schema: 1, cutoff: "0.1.0-alpha.22", releases: [] }),
  };
}

test("main discovery catches up a suppressed bot merge and chooses the oldest registered immutable source", async () => {
  const discovered = await discoverPendingRelease(capabilities(), { repository, cutoff: 22 });
  assert.equal(discovered._tag, "Selected");
  assert.equal(discovered.release.version, "0.1.0-alpha.23");
  assert.equal(discovered.release.sourceSha, merge23);
  const scheduledRetry = await discoverPendingRelease(capabilities(), { repository, cutoff: 22 });
  assert.deepEqual(scheduledRetry, discovered);
});

test("main movement does not relabel an already selected source and a stale checkout is rejected", async () => {
  const latestMain = "f".repeat(40);
  const current = await discoverPendingRelease(
    capabilities({ mainSha: latestMain }),
    { repository, cutoff: 22 },
  );
  assert.equal(current.release.sourceSha, merge23);
  const stale = capabilities({ mainSha: latestMain });
  stale.head = () => tip;
  await assert.rejects(discoverPendingRelease(stale, { repository, cutoff: 22 }),
    /current trusted main/);
});

test("registered PR identity and missing checkpoint registration fail closed", async () => {
  const spoofed = registeredPr(57, merge23);
  spoofed.user.login = "attacker";
  await assert.rejects(discoverPendingRelease(
    capabilities({ pulls: [spoofed] }), { repository, cutoff: 22 },
  ), /identity mismatch/);
  const missingAtMerge = capabilities();
  missingAtMerge.readCheckpointAt = () => ({ baseline, automation: [58] });
  await assert.rejects(discoverPendingRelease(missingAtMerge, { repository, cutoff: 22 }),
    /not registered at its merge/);
});
