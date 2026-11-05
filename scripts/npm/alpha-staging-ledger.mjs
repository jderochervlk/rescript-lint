const digestPattern = /^sha512-([A-Za-z0-9+/]{86}==)$/;
const shaPattern = /^[a-f0-9]{40}$/;
const versionPattern = /^0\.1\.0-alpha\.([1-9]\d*)$/;
const packageNames = [
  "@jvlk/rescript-lint-linux-x64-gnu",
  "@jvlk/rescript-lint-linux-arm64-gnu",
  "@jvlk/rescript-lint-darwin-x64",
  "@jvlk/rescript-lint-darwin-arm64",
  "@jvlk/rescript-lint-win32-x64",
  "@jvlk/rescript-lint",
];

function record(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value) &&
    Object.getPrototypeOf(value) === Object.prototype;
}

function exactKeys(value, required, optional = []) {
  const keys = Object.keys(value);
  return required.every(key => keys.includes(key)) &&
    keys.every(key => required.includes(key) || optional.includes(key));
}

function alphaCounter(version) {
  if (typeof version !== "string") return undefined;
  const match = versionPattern.exec(version);
  if (!match) return undefined;
  const counter = Number(match[1]);
  return Number.isSafeInteger(counter) ? counter : undefined;
}

export function validateLedger(ledger) {
  if (!record(ledger) || !exactKeys(ledger, ["schema", "cutoff", "releases"]) ||
      ledger.schema !== 1 || !Array.isArray(ledger.releases) ||
      alphaCounter(ledger.cutoff) === undefined) {
    throw new Error("Invalid alpha staging ledger schema");
  }
  const versions = new Set();
  const sources = new Set();
  const pullRequests = new Set();
  const attempts = new Set();
  for (const release of ledger.releases) {
    if (!record(release) ||
        !exactKeys(release, ["version", "sourceSha", "pullRequest", "originalRun", "runId",
          "attemptId", "packages", "status", "accepted"], ["reason"]) ||
        alphaCounter(release.version) === undefined ||
        alphaCounter(release.version) <= alphaCounter(ledger.cutoff) ||
        typeof release.sourceSha !== "string" ||
        !shaPattern.test(release.sourceSha) ||
        !Number.isSafeInteger(release.pullRequest) || release.pullRequest < 1 ||
        !Number.isSafeInteger(release.originalRun) || release.originalRun < 1 ||
        typeof release.runId !== "string" || !/^\d+$/.test(release.runId) ||
        typeof release.attemptId !== "string" || !release.attemptId ||
        !Array.isArray(release.packages) || release.packages.length !== 6 ||
        !Array.isArray(release.accepted)) {
      throw new Error("Invalid release identity or package set in alpha staging ledger");
    }
    if (versions.has(release.version)) throw new Error(`Duplicate ledger version ${release.version}`);
    if (sources.has(release.sourceSha) || pullRequests.has(release.pullRequest) ||
        attempts.has(release.attemptId)) {
      throw new Error(`Conflicting release ownership in alpha staging ledger`);
    }
    versions.add(release.version);
    sources.add(release.sourceSha);
    pullRequests.add(release.pullRequest);
    attempts.add(release.attemptId);
    for (const [index, entry] of release.packages.entries()) {
      if (!record(entry) || !exactKeys(entry, ["name", "artifact", "digest"]) ||
          typeof entry.name !== "string" || entry.name !== packageNames[index] ||
          typeof entry.artifact !== "string" || !entry.artifact ||
          typeof entry.digest !== "string" ||
          !digestPattern.test(entry.digest) ||
          Buffer.from(entry.digest.slice("sha512-".length), "base64").length !== 64) {
        throw new Error(`Invalid package evidence for ${release.version}`);
      }
    }
    if (!["Attempting", "NeedsInspection", "Staged"].includes(release.status)) {
      throw new Error(`Invalid staging status for ${release.version}`);
    }
    if (release.status === "NeedsInspection"
      ? typeof release.reason !== "string" || !release.reason.trim()
      : release.reason !== undefined) {
      throw new Error(`Invalid inspection outcome for ${release.version}`);
    }
    if (release.accepted.length > 6 ||
        (release.status === "Staged" && release.accepted.length !== 6) ||
        release.accepted.some((accepted, index) =>
          !record(accepted) || !exactKeys(accepted, ["name", "stageId"]) ||
          accepted.name !== packageNames[index] ||
          typeof accepted.stageId !== "string" || !accepted.stageId) ||
        new Set(release.accepted.map(accepted => accepted.stageId)).size !== release.accepted.length ||
        (release.status === "NeedsInspection" && (typeof release.reason !== "string" || !release.reason.trim()))) {
      throw new Error(`Incomplete staged release ${release.version}`);
    }
  }
  return ledger;
}

export function beginAttempt(ledger, candidate) {
  validateLedger(ledger);
  validateCandidate(candidate);
  const existing = ledger.releases.find(item => item.version === candidate.version);
  if (existing) {
    if (existing.sourceSha !== candidate.sourceSha ||
        existing.pullRequest !== candidate.pullRequest) {
      throw new Error(`Conflicting release identity for ${candidate.version}`);
    }
    if (existing.status === "Staged") return { _tag: "AlreadyStaged", ledger, release: existing };
    throw new Error(`Release ${candidate.version} requires maintainer inspection`);
  }
  const release = { ...candidate, status: "Attempting", accepted: [] };
  return { _tag: "AttemptStarted", ledger: { ...ledger, releases: [...ledger.releases, release] }, release };
}

export function recordAccepted(ledger, version, packageName, stageId) {
  validateLedger(ledger);
  const release = findRelease(ledger, version);
  if (release.status !== "Attempting") throw new Error(`Release ${version} is not accepting progress`);
  const expected = release.packages[release.accepted.length];
  if (!expected || expected.name !== packageName || typeof stageId !== "string" || !stageId) {
    throw new Error(`Unexpected staging progress for ${version}`);
  }
  const updated = { ...release, accepted: [...release.accepted, { name: packageName, stageId }] };
  return replaceRelease(ledger, updated);
}

export function finishAttempt(ledger, version) {
  validateLedger(ledger);
  const release = findRelease(ledger, version);
  if (release.status !== "Attempting" || release.accepted.length !== 6) {
    throw new Error(`Cannot complete incomplete release ${version}`);
  }
  return replaceRelease(ledger, { ...release, status: "Staged" });
}

export function requireInspection(ledger, version, reason) {
  validateLedger(ledger);
  if (typeof reason !== "string" || !reason.trim()) throw new Error("Inspection reason is required");
  const release = findRelease(ledger, version);
  if (release.status !== "Attempting") throw new Error(`Release ${version} is not in progress`);
  return replaceRelease(ledger, { ...release, status: "NeedsInspection", reason });
}

function validateCandidate(candidate) {
  if (!record(candidate) || typeof candidate.version !== "string" ||
      alphaCounter(candidate.version) === undefined ||
      !shaPattern.test(candidate.sourceSha ?? "") ||
      !Number.isSafeInteger(candidate.pullRequest) || candidate.pullRequest < 1 ||
      !Number.isSafeInteger(candidate.originalRun) || candidate.originalRun < 1 ||
      typeof candidate.runId !== "string" || !candidate.runId ||
      typeof candidate.attemptId !== "string" || !candidate.attemptId ||
      !Array.isArray(candidate.packages) || candidate.packages.length !== 6) {
    throw new Error("Invalid release candidate identity or package set");
  }
  validateLedger({ schema: 1, cutoff: "0.1.0-alpha.1", releases: [
    { ...candidate, status: "Attempting", accepted: [] },
  ] });
}

function findRelease(ledger, version) {
  const release = ledger.releases.find(item => item.version === version);
  if (!release) throw new Error(`Unknown release ${version}`);
  return release;
}

function replaceRelease(ledger, replacement) {
  return { ...ledger, releases: ledger.releases.map(item =>
    item.version === replacement.version ? replacement : item) };
}
