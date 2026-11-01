export const branch = "automation/alpha-version";
export const statePath = ".github/alpha-version-state.json";

export function validateState(state) {
  if (state.schema !== 1 || !/^[a-f0-9]{40}$/.test(state.baseline) ||
      !Array.isArray(state.sources) || !Array.isArray(state.automation)) {
    throw new Error("Invalid version checkpoint");
  }
  const ids = [...state.sources, ...state.automation];
  if (ids.some(id => !Number.isSafeInteger(id) || id <= 0) || new Set(ids).size !== ids.length) {
    throw new Error("Invalid or duplicate checkpoint PR IDs");
  }
  return state;
}

export function owned(pr, { repository, bot }) {
  return pr.user.login === bot && pr.head.ref === branch &&
    pr.head.repo?.full_name === repository && pr.base.ref === "main" &&
    pr.base.repo.full_name === repository;
}

export function ownedCommit(commit, { bot }) {
  if (commit?.author?.login !== bot) return false;
  const verification = commit.commit?.verification;
  return commit.committer?.login === bot ||
    (commit.committer?.login === "web-flow" &&
      verification?.verified === true && verification.reason === "valid");
}

// The caller supplies ancestry-filtered PRs, not event payloads or timestamps.
export function reconcile(state, merged, identity) {
  validateState(state);
  const seen = new Set(state.sources);
  const automation = new Set(state.automation);
  const sourceIds = [];
  for (const pr of merged) {
    if (!pr.merged_at || pr.base.ref !== "main" || pr.base.repo.full_name !== identity.repository) continue;
    if (automation.has(pr.number)) {
      if (!owned(pr, identity)) throw new Error(`Automation identity mismatch for #${pr.number}`);
      continue;
    }
    if (owned(pr, identity)) throw new Error(`Unregistered automation PR #${pr.number}; inspect checkpoint`);
    if (!seen.has(pr.number)) {
      seen.add(pr.number);
      sourceIds.push(pr.number);
    }
  }
  sourceIds.sort((a, b) => a - b);
  return { count: sourceIds.length, included: sourceIds,
    state: { ...state, sources: [...seen].sort((a, b) => a - b) } };
}

export function recordAutomation(state, number) {
  if (state.sources.includes(number)) throw new Error("Source PR cannot become automation");
  return validateState({ ...state, automation: [...new Set([...state.automation, number])].sort((a, b) => a - b) });
}
