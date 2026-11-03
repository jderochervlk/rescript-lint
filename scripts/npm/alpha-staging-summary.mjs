export function releaseSummary({ result, releaseRecord, packages, env, sourceSha, version, pullRequest, runId }) {
  const status = releaseRecord?.status ?? "NoAttempt";
  const outcome = result._tag === "AlreadyStaged" ? "No-op: AlreadyStaged" : result._tag;
  const lines = [
    "# Alpha release staging",
    `- Outcome: **${outcome}**`,
    `- Version: \`${version}\`; registered version PR: #${pullRequest}`,
    `- Source SHA: \`${sourceSha}\``,
    `- Run: ${env.GITHUB_SERVER_URL ?? "https://github.com"}/${env.GITHUB_REPOSITORY}/actions/runs/${runId}`,
    `- Original staging run: ${releaseRecord?.runId ?? "none"}`,
    `- Ledger state: **${status}**`,
    "",
    "| Package | Outcome | Stage ID | SHA-512 |",
    "| --- | --- | --- | --- |",
  ];
  for (const entry of packages) {
    const accepted = releaseRecord?.accepted.find(item => item.name === entry.name);
    const packageOutcome = accepted ? "Accepted" : status === "NeedsInspection" ? "Inspect" : "Not uploaded";
    lines.push(`| ${entry.name} | ${packageOutcome} | ${accepted?.stageId ?? "—"} | \`${entry.digest ?? "unavailable"}\` |`);
  }
  lines.push("", `- Result detail: ${result.message ?? (status === "Staged" ? "All six packages are staged; publication still requires npm maintainer 2FA." : "No further output.")}`);
  const action = result._tag === "AlreadyStaged"
    ? `No-op: no uploads performed; see original run ${releaseRecord.runId}.`
    : status === "Staged"
      ? "Review each npm stage, then approve the five native packages before the launcher with 2FA."
      : status === "NeedsInspection" || status === "Attempting"
        ? "Stop. Inspect the ledger and every npm stage; do not retry this version automatically."
        : "No staging attempt was recorded; resolve the reported preflight or artifact issue before a new request.";
  lines.push(`- Maintainer action: ${action}`);
  return lines.join("\n");
}
