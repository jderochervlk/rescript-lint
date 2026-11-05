import test from "node:test";
import assert from "node:assert/strict";
import { beginAttempt } from "../../scripts/npm/alpha-staging-ledger.mjs";
import { selectPendingRelease } from "../../scripts/version/alpha-release-selection.mjs";

const repository = "owner/project";
const checkpoint = { baseline: "b".repeat(40), automation: [56, 57, 58] };
const mainSha = "c".repeat(40);
const emptyLedger = { schema: 1, cutoff: "0.1.0-alpha.22", releases: [] };
const packageNames = [
  "@jvlk/rescript-lint-linux-x64-gnu", "@jvlk/rescript-lint-linux-arm64-gnu",
  "@jvlk/rescript-lint-darwin-x64", "@jvlk/rescript-lint-darwin-arm64",
  "@jvlk/rescript-lint-win32-x64", "@jvlk/rescript-lint",
];
function evidence(status, version = "0.1.0-alpha.23") {
  const release = {
    version, sourceSha: pr(57, 23).merge_commit_sha, pullRequest: 57,
    originalRun: 42, runId: "42", attemptId: `42-${"a".repeat(40)}`,
    packages: packageNames.map((name, index) => ({
      name, artifact: `artifact-${index}`,
      digest: `sha512-${Buffer.alloc(64, index + 1).toString("base64")}`,
    })),
    status,
    accepted: status === "Staged"
      ? packageNames.map((name, index) => ({ name, stageId: `stage-${index}` }))
      : [],
  };
  if (status === "NeedsInspection") release.reason = "operator inspection";
  return release;
}
function pr(number, sequence, sourceSha = String(number).padStart(40, "a")) {
  return {
    number, repository, state: "closed", merged_at: "2026-11-02T12:00:00Z",
    merge_commit_sha: sourceSha, version: `0.1.0-alpha.${sequence}`,
    onMain: true, afterCheckpoint: true,
    base: { ref: "main", repo: { full_name: repository } },
    head: { ref: "automation/alpha-version", repo: { full_name: repository } },
    user: { login: "github-actions[bot]" },
  };
}

function select(pullRequests, ledger = emptyLedger, requestedVersion) {
  return selectPendingRelease({
    pullRequests, checkpoint, mainSha, cutoff: 22, ledger, repository, requestedVersion,
  });
}

test("selects oldest pending eligible merged version, not newest main tip", () => {
  const result = select([pr(58, 24), pr(57, 23), pr(56, 22)]);
  assert.equal(result._tag, "Selected");
  assert.equal(result.release.version, "0.1.0-alpha.23");
  assert.equal(result.release.pullRequest, 57);
});

test("no eligible registered merge yields a no-candidate outcome", () => {
  assert.deepEqual(select([]), { _tag: "NoCandidate" });
  assert.deepEqual(select([pr(57, 22)]), { _tag: "NoCandidate" });
});

test("completed ledger entries are skipped while later releases remain pending", () => {
  const completed = evidence("Staged");
  const result = select([pr(56, 22), pr(57, 23), pr(58, 24)], {
    schema: 1, cutoff: "0.1.0-alpha.22", releases: [completed],
  });
  assert.equal(result.release.version, "0.1.0-alpha.24");
  const duplicateTag = selectPendingRelease({
    pullRequests: [pr(57, 23)], checkpoint, mainSha, cutoff: 22,
    ledger: { schema: 1, cutoff: "0.1.0-alpha.22", releases: [completed] },
    repository, requestedVersion: "0.1.0-alpha.23",
  });
  assert.equal(duplicateTag._tag, "AlreadyStaged");
});

test("conflicting or spoofed registered history fails closed", () => {
  assert.throws(() => select([pr(57, 23, "d".repeat(40)), pr(58, 23, "e".repeat(40))]), /Conflicting source ownership/);
  assert.throws(() => select([pr(57, 23, "invalid")]), /not a canonical merged release/);
  assert.throws(() => select([{ ...pr(57, 23), user: { login: "attacker" } }]), /invalid identity/);
  assert.throws(() => select([{ ...pr(57, 23), onMain: false }]), /not a canonical merged release/);
});

test("an unresolved earlier attempt blocks later releases", () => {
  for (const status of ["Attempting", "NeedsInspection"]) {
    const unfinished = { ...evidence(status, "0.1.0-alpha.23"),
      sourceSha: pr(57, 23).merge_commit_sha, pullRequest: 57 };
    assert.throws(() => select([pr(57, 23), pr(58, 24)], {
      schema: 1, cutoff: "0.1.0-alpha.22", releases: [unfinished],
    }), /requires maintainer inspection/);
    assert.throws(() => select([pr(57, 23), pr(58, 24)], {
      schema: 1, cutoff: "0.1.0-alpha.22", releases: [unfinished],
    }, "0.1.0-alpha.24"), /requires maintainer inspection/);
  }
});

test("completed requested tags still validate all owners independently of PR order", () => {
  const complete23 = evidence("Staged");
  const original = pr(57, 23);
  const conflicting = pr(58, 23, "e".repeat(40));
  for (const pulls of [[original, conflicting], [conflicting, original]]) {
    assert.throws(() => select(pulls, {
      schema: 1, cutoff: "0.1.0-alpha.22", releases: [complete23],
    }, "0.1.0-alpha.23"), /Conflicting source ownership|Ledger identity conflicts/);
  }
});

test("malformed scalar ledger identities fail before selection or attempt creation", () => {
  const malformed = evidence("Staged");
  malformed.version = ["0.1.0-alpha.23"];
  const ledger = { schema: 1, cutoff: "0.1.0-alpha.22", releases: [malformed] };
  assert.throws(() => selectPendingRelease({
    pullRequests: [pr(57, 23)], checkpoint, mainSha, cutoff: 22,
    ledger, repository,
  }), /Invalid release identity/);
  assert.throws(() => beginAttempt(ledger, {
    version: "0.1.0-alpha.24", sourceSha: "f".repeat(40), pullRequest: 58,
    originalRun: 123, runId: "123", attemptId: "123-attempt", packages: malformed.packages,
  }), /Invalid release identity/);
});
