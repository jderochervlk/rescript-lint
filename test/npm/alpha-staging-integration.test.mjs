import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { beginAttempt, finishAttempt, recordAccepted } from "../../scripts/npm/alpha-staging-ledger.mjs";
import { stageRelease } from "../../scripts/npm/stage-release.mjs";

const names = [
  "@jvlk/rescript-lint-linux-x64-gnu", "@jvlk/rescript-lint-linux-arm64-gnu",
  "@jvlk/rescript-lint-darwin-x64", "@jvlk/rescript-lint-darwin-arm64",
  "@jvlk/rescript-lint-win32-x64", "@jvlk/rescript-lint",
];

test("trusted staging orchestration claims, uploads native-first, completes, and makes duplicates no-op", async () => {
  const directory = mkdtempSync(join(tmpdir(), "alpha-stage-flow-"));
  try {
    const packages = names.map((name, index) => {
      const tarball = join(directory, `${index}.tgz`);
      writeFileSync(tarball, `verified package ${name}`);
      return { name, tarball };
    });
    let ledger = { schema: 1, cutoff: "0.1.0-alpha.22", releases: [] };
    const uploads = [];
    const context = {
      packages,
      env: {
        ACTIONS_ID_TOKEN_REQUEST_URL: "https://oidc.example/token",
        ACTIONS_ID_TOKEN_REQUEST_TOKEN: "test",
      },
      request: async url => ({
        ok: true,
        json: async () => String(url).includes("oidc.example")
          ? { value: "oidc-test" } : { token: "npm-test" },
      }),
      exists: () => true,
      stage: async entry => {
        uploads.push(entry.name);
        return { _tag: "PackageStaged", stageId: `stage-${uploads.length}` };
      },
      beginAttempt: evidence => {
        const prepared = beginAttempt(ledger, {
          version: "0.1.0-alpha.23", sourceSha: "a".repeat(40), pullRequest: 57,
          originalRun: 101, runId: "101", attemptId: `101-${"a".repeat(40)}`,
          packages: evidence.map(entry => ({
            name: entry.name, artifact: entry.tarball, digest: entry.digest,
          })),
        });
        ledger = prepared.ledger;
        return prepared;
      },
      onAccepted: (_entry, id) => {
        const name = names[ledger.releases[0].accepted.length];
        ledger = recordAccepted(ledger, "0.1.0-alpha.23", name, id);
      },
      completeAttempt: () => { ledger = finishAttempt(ledger, "0.1.0-alpha.23"); },
      inspectAttempt: () => assert.fail("successful staging should not need inspection"),
    };
    const completed = await stageRelease(context);
    assert.equal(completed._tag, "ReleaseStaged");
    assert.deepEqual(uploads, names);
    assert.equal(ledger.releases[0].status, "Staged");
    assert.equal(ledger.releases[0].accepted.length, 6);
    const duplicate = await stageRelease(context);
    assert.equal(duplicate._tag, "AlreadyStaged");
    assert.equal(uploads.length, 6);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
