import test from "node:test";
import assert from "node:assert/strict";
import {
  beginAttempt, finishAttempt, recordAccepted, requireInspection, validateLedger,
} from "../../scripts/npm/alpha-staging-ledger.mjs";

const packageNames = [
  "@jvlk/rescript-lint-linux-x64-gnu", "@jvlk/rescript-lint-linux-arm64-gnu",
  "@jvlk/rescript-lint-darwin-x64", "@jvlk/rescript-lint-darwin-arm64",
  "@jvlk/rescript-lint-win32-x64", "@jvlk/rescript-lint",
];
const packages = packageNames.map((name, index) => ({
  name,
  artifact: `run-42/packages-${index}.tgz`,
  digest: `sha512-${Buffer.alloc(64, index + 1).toString("base64")}`,
}));
const candidate = {
  version: "0.1.0-alpha.23",
  pullRequest: 57,
  sourceSha: "a".repeat(40),
  originalRun: 42,
  runId: "42",
  attemptId: `42-${"a".repeat(40)}`,
  packages,
};
const empty = { schema: 1, cutoff: "0.1.0-alpha.22", releases: [] };

test("ledger attempt is immutable and completes only after six ordered uploads", () => {
  const started = beginAttempt(empty, candidate);
  assert.equal(started._tag, "AttemptStarted");
  assert.deepEqual(empty.releases, []);
  assert.throws(() => finishAttempt(started.ledger, candidate.version), /incomplete/);
  const progress = packages.reduce((state, entry, index) =>
    recordAccepted(state, candidate.version, entry.name, `stage-${index}`), started.ledger);
  const completed = finishAttempt(progress, candidate.version);
  assert.equal(completed.releases[0].status, "Staged");
  assert.equal(beginAttempt(completed, candidate)._tag, "AlreadyStaged");
  assert.throws(() => recordAccepted(completed, candidate.version, packageNames[0], "stage-again"),
    /not accepting progress/);
});

test("incomplete and conflicting attempts fail closed", () => {
  const started = beginAttempt(empty, candidate);
  assert.throws(() => beginAttempt(started.ledger, candidate), /requires maintainer inspection/);
  assert.throws(() => beginAttempt(started.ledger, { ...candidate, sourceSha: "b".repeat(40) }),
    /Conflicting release identity/);
  assert.throws(() => recordAccepted(started.ledger, candidate.version, packageNames[1], "stage"),
    /Unexpected staging progress/);
  const inspected = requireInspection(started.ledger, candidate.version, "Upload timed out");
  assert.equal(inspected.releases[0].status, "NeedsInspection");
  assert.throws(() => beginAttempt(inspected, candidate), /requires maintainer inspection/);
});

test("invalid ledger shape and package evidence are rejected", () => {
  assert.throws(() => validateLedger({ schema: 2, releases: [] }), /schema/);
  assert.throws(() => validateLedger(null), /schema/);
  assert.throws(() => validateLedger({ ...empty, extra: true }), /schema/);
  assert.throws(() => validateLedger({ ...empty, cutoff: ["0.1.0-alpha.22"] }), /schema/);
  assert.throws(() => validateLedger({ ...empty, cutoff: "0.1.0-alpha.99999999999999999999" }), /schema/);
  assert.throws(() => validateLedger({ ...empty, releases: {} }), /schema/);
  assert.throws(() => beginAttempt(empty, { ...candidate, packages: packages.slice(1) }), /package set/);
  assert.throws(() => beginAttempt(empty, {
    ...candidate, packages: [{ ...packages[0], digest: "not-a-digest" }, ...packages.slice(1)],
  }), /package evidence/);
  const validAttempt = { ...candidate, status: "Attempting", accepted: [] };
  const invalidRelease = changes => assert.throws(() =>
    validateLedger({ ...empty, releases: [{ ...validAttempt, ...changes }] }));
  invalidRelease({ version: ["0.1.0-alpha.23"] });
  invalidRelease({ sourceSha: ["a".repeat(40)] });
  invalidRelease({ pullRequest: "57" });
  invalidRelease({ runId: 42 });
  invalidRelease({ attemptId: ["id"] });
  invalidRelease({ extra: true });
  invalidRelease({ status: "Unknown" });
  invalidRelease({ status: "NeedsInspection", reason: "" });
  invalidRelease({ reason: "not inspecting" });
  invalidRelease({ accepted: "no" });
  invalidRelease({ packages: "no" });
  invalidRelease({ packages: [{ ...packages[0], extra: "field" }, ...packages.slice(1)] });
  invalidRelease({ packages: [{ ...packages[0], name: ["package"] }, ...packages.slice(1)] });
  invalidRelease({ packages: [{ ...packages[0], artifact: "" }, ...packages.slice(1)] });
  invalidRelease({ packages: [{ ...packages[0], digest: 12 }, ...packages.slice(1)] });
  invalidRelease({ accepted: [{ name: packageNames[0], stageId: "stage", extra: true }] });
  invalidRelease({ accepted: [{ name: packageNames[0], stageId: "" }] });
  invalidRelease({ accepted: [{ name: packageNames[1], stageId: "stage" }] });

  assert.throws(() => validateLedger({ ...empty, releases: [
    validAttempt, { ...validAttempt, version: "0.1.0-alpha.24" },
  ] }), /Conflicting release ownership/);
  assert.throws(() => validateLedger({ ...empty, releases: [
    validAttempt, { ...validAttempt, version: "0.1.0-alpha.24", sourceSha: "b".repeat(40) },
  ] }), /Conflicting release ownership/);
  assert.throws(() => validateLedger({ ...empty, releases: [
    validAttempt, { ...validAttempt, version: "0.1.0-alpha.24", pullRequest: 58 },
  ] }), /Conflicting release ownership/);
});
