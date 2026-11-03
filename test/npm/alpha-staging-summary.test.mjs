import assert from "node:assert/strict";
import { test } from "node:test";
import { releaseSummary } from "../../scripts/npm/alpha-staging-summary.mjs";

const names = [
  "@jvlk/rescript-lint-linux-x64-gnu", "@jvlk/rescript-lint-linux-arm64-gnu",
  "@jvlk/rescript-lint-darwin-x64", "@jvlk/rescript-lint-darwin-arm64",
  "@jvlk/rescript-lint-win32-x64", "@jvlk/rescript-lint",
];
const packages = names.map((name, index) => ({
  name, digest: `sha512-${Buffer.alloc(64, index + 1).toString("base64")}`,
}));
const base = {
  packages, sourceSha: "a".repeat(40), version: "0.1.0-alpha.23",
  pullRequest: 57, runId: "101", env: {
    GITHUB_SERVER_URL: "https://github.com",
    GITHUB_REPOSITORY: "jderochervlk/rescript-lint",
  },
};

test("completed staging summary includes all package stage IDs and next approval action", () => {
  const summary = releaseSummary({
    ...base,
    result: { _tag: "ReleaseStaged" },
    releaseRecord: {
      version: base.version, pullRequest: base.pullRequest, sourceSha: base.sourceSha,
      runId: base.runId, status: "Staged",
      accepted: names.map((name, index) => ({ name, stageId: `stage-${index + 1}` })),
    },
  });
  assert.match(summary, /stage-1/);
  assert.match(summary, /stage-6/);
  assert.match(summary, /Ledger state: \*\*Staged\*\*/);
  assert.match(summary, /approve the five native packages before the launcher/);
  assert.match(summary, /publication still requires npm maintainer 2FA/);
});

test("already-completed requests are clearly no-op summaries", () => {
  const summary = releaseSummary({
    ...base,
    result: { _tag: "AlreadyStaged" },
    releaseRecord: {
      version: base.version, runId: base.runId, status: "Staged",
      accepted: names.map((name, index) => ({ name, stageId: `stage-${index + 1}` })),
    },
  });
  assert.match(summary, /No-op: AlreadyStaged/);
  assert.match(summary, /No-op: no uploads performed; see original run 101/);
});

test("inspection summaries preserve known prefix stage IDs and stop unsafe retries", () => {
  const summary = releaseSummary({
    ...base,
    result: { _tag: "StageOutcomeUnknown", message: "Inspect pending stage." },
    releaseRecord: {
      version: base.version, runId: base.runId, status: "NeedsInspection",
      accepted: names.slice(0, 2).map((name, index) => ({ name, stageId: `stage-${index + 1}` })),
    },
  });
  assert.match(summary, /stage-2/);
  assert.match(summary, /Inspect/);
  assert.match(summary, /do not retry this version automatically/);

  const interrupted = releaseSummary({
    ...base,
    result: { _tag: "StagingFailed", message: "Ledger update failed." },
    releaseRecord: { version: base.version, runId: base.runId, status: "Attempting", accepted: [] },
  });
  assert.match(interrupted, /Ledger state: \*\*Attempting\*\*/);
  assert.match(interrupted, /Stop\. Inspect the ledger/);
});

test("preflight summary handles absent ledger, digest, stage ID, and Actions summary URL", () => {
  const summary = releaseSummary({
    ...base,
    env: { GITHUB_REPOSITORY: base.env.GITHUB_REPOSITORY },
    packages: [{ name: names[0] }],
    result: { _tag: "PublisherUnavailable", message: "Authentication preflight failed." },
    releaseRecord: undefined,
  });
  assert.match(summary, /NoAttempt/);
  assert.match(summary, /Original staging run: none/);
  assert.match(summary, /https:\/\/github\.com\/jderochervlk/);
  assert.match(summary, /Not uploaded/);
  assert.match(summary, /unavailable/);
  assert.match(summary, /Authentication preflight failed/);
  assert.match(summary, /No staging attempt was recorded/);
});
