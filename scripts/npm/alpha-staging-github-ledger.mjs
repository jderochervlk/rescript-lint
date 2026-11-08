import { validateLedger } from "./alpha-staging-ledger.mjs";

export const ledgerBranch = "automation/alpha-staging-state";
export const ledgerPath = "alpha-staging-ledger.json";

export async function readLedger(api, repository) {
  const ref = await api(`repos/${repository}/git/ref/heads/${ledgerBranch}`);
  const commit = await api(`repos/${repository}/git/commits/${ref.object.sha}`);
  if (commit.sha !== ref.object.sha || !Array.isArray(commit.parents) ||
      commit.parents.length > 1) {
    throw new Error("Alpha staging ledger commit has invalid ancestry");
  }
  const tree = await api(`repos/${repository}/git/trees/${commit.tree.sha}?recursive=1`);
  if (tree.truncated || !Array.isArray(tree.tree) || tree.tree.length !== 1 ||
      tree.tree[0].path !== ledgerPath || tree.tree[0].type !== "blob" ||
      tree.tree[0].mode !== "100644") {
    throw new Error("Alpha staging ledger tree must contain only its data file");
  }
  const file = await api(`repos/${repository}/contents/${ledgerPath}?ref=${ref.object.sha}`);
  if (file.encoding !== "base64" || typeof file.content !== "string") {
    throw new Error("Alpha staging ledger contents response is invalid");
  }
  const text = Buffer.from(file.content, "base64").toString("utf8");
  let ledger;
  try {
    ledger = JSON.parse(text);
  } catch {
    throw new Error("Alpha staging ledger is corrupt; operator inspection required");
  }
  return { tip: ref.object.sha, tree: commit.tree.sha, ledger: validateLedger(ledger) };
}

export async function commitLedger({ api, repository, observed, next, message }) {
  validateLedger(next);
  const current = await readLedger(api, repository);
  if (current.tip !== observed.tip) throw new Error("Alpha staging ledger advanced; reread and replan");
  const blob = await api(`repos/${repository}/git/blobs`, "POST", {
    content: `${JSON.stringify(next, null, 2)}\n`, encoding: "utf-8",
  });
  const tree = await api(`repos/${repository}/git/trees`, "POST", {
    base_tree: observed.tree,
    tree: [{ path: ledgerPath, mode: "100644", type: "blob", sha: blob.sha }],
  });
  const commit = await api(`repos/${repository}/git/commits`, "POST", {
    message, tree: tree.sha, parents: [observed.tip],
  });
  if (!Array.isArray(commit.parents) || commit.parents.length !== 1 ||
      commit.parents[0].sha !== observed.tip) {
    throw new Error("Ledger commit is not a single child of the observed tip");
  }
  try {
    await api(`repos/${repository}/git/refs/heads/${ledgerBranch}`, "PATCH", {
      sha: commit.sha, force: false,
    });
  } catch (error) {
    const after = await readLedger(api, repository);
    if (after.tip !== commit.sha) {
      throw new Error(`Ledger ref update was not confirmed; observed ${after.tip}`, { cause: error });
    }
  }
  const confirmed = await readLedger(api, repository);
  if (confirmed.tip !== commit.sha || JSON.stringify(confirmed.ledger) !== JSON.stringify(next)) {
    throw new Error("Ledger write was not confirmed exactly; stop for operator inspection");
  }
  return confirmed;
}

export async function bootstrapLedger({ api, repository, authorized, cutoff }) {
  if (authorized !== true) throw new Error("Ledger bootstrap requires explicit operator authorization");
  const refs = await api(`repos/${repository}/git/matching-refs/heads/${ledgerBranch}`);
  if (refs.some(ref => ref.ref === `refs/heads/${ledgerBranch}`)) {
    throw new Error("Ledger already exists; bootstrap never resets existing state");
  }
  if (!Number.isSafeInteger(cutoff) || cutoff < 1) throw new Error("Reviewed alpha cutoff is required");
  const tree = await api(`repos/${repository}/git/trees`, "POST", {
    tree: [{
      path: ledgerPath, mode: "100644", type: "blob",
      content: `${JSON.stringify({ schema: 1, cutoff: `0.1.0-alpha.${cutoff}`, releases: [] }, null, 2)}\n`,
    }],
  });
  const commit = await api(`repos/${repository}/git/commits`, "POST", {
    message: `chore(release): bootstrap alpha staging ledger at alpha.${cutoff}`,
    tree: tree.sha, parents: [],
  });
  await api("repos/" + repository + "/git/refs", "POST", {
    ref: `refs/heads/${ledgerBranch}`, sha: commit.sha,
  });
  return readLedger(api, repository);
}
