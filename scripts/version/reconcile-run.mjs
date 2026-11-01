import { plan, paths } from "./version.mjs";
import { branch, statePath, owned, reconcile, recordAutomation } from "./reconcile.mjs";

function allPulls(api, repository) {
  const pulls = [];
  for (let page = 1; ; page++) {
    const batch = api(`repos/${repository}/pulls?state=all&per_page=100&page=${page}`);
    pulls.push(...batch);
    if (batch.length < 100) return pulls;
  }
}

function workflowIdentity(env) {
  const repository = env.GITHUB_REPOSITORY;
  if (!repository || !env.GH_TOKEN || env.GITHUB_ACTIONS !== "true" ||
      env.GITHUB_REF !== "refs/heads/main") {
    throw new Error("Requires GITHUB_TOKEN in GitHub Actions on trusted main");
  }
  return { repository, bot: "github-actions[bot]" };
}

function loadSnapshot({ api, head, ancestor, readVersions, readCheckpoint }, identity) {
  const repo = `repos/${identity.repository}`;
  const mainSha = api(`${repo}/git/ref/heads/main`).object.sha;
  if (head() !== mainSha) throw new Error("Checkout is not current trusted main; retry");
  const original = readVersions(".");
  plan(original);
  const checkpoint = readCheckpoint();
  if (!ancestor(checkpoint.baseline, mainSha)) throw new Error("Checkpoint baseline is not on main");
  const pulls = allPulls(api, identity.repository);
  const merged = pulls.filter(pr => pr.merged_at && pr.base.ref === "main" &&
    ancestor(pr.merge_commit_sha, mainSha) && !ancestor(pr.merge_commit_sha, checkpoint.baseline));
  const result = reconcile(checkpoint, merged, identity);
  const pending = pulls.filter(pr => pr.state === "open" && pr.head.ref === branch &&
    pr.head.repo?.full_name === identity.repository);
  if (pending.length > 1 || pending.some(pr => !owned(pr, identity))) throw new Error("Version branch PR ownership conflict");
  return { repo, mainSha, original, result, pr: pending[0], identity };
}

function verifyBranch(api, { repo, mainSha, pr, identity }) {
  // A missing ref is expected only for the very first run; do not hide API errors.
  const refs = api(`${repo}/git/matching-refs/heads/${branch}`);
  const existing = refs.find(ref => ref.ref === `refs/heads/${branch}`);
  if (!existing) {
    if (pr) throw new Error("Pending PR branch disappeared");
    return undefined;
  }
  const oldHead = existing.object.sha;
  const commit = api(`${repo}/commits/${oldHead}`);
  if (commit.committer?.login !== identity.bot) throw new Error("Version branch was modified outside GitHub Actions");
  const diff = api(`${repo}/compare/${mainSha}...${oldHead}`);
  const allowed = new Set([...paths, statePath]);
  if (!diff.files || diff.files.length >= 300 || diff.files.some(file => !allowed.has(file.filename))) {
    throw new Error("Unexpected files on version branch; inspect before retry");
  }
  return oldHead;
}

function assertFresh(api, { repo, mainSha }, oldHead) {
  if (api(`${repo}/git/ref/heads/main`).object.sha !== mainSha) throw new Error("Main advanced; reconcile again");
  if (oldHead && api(`${repo}/git/ref/heads/${branch}`).object.sha !== oldHead) {
    throw new Error("Version branch advanced; reconcile again");
  }
}

function graph(api, query, variables) {
  return api("graphql", "POST", { query, variables });
}

function disableAutoMerge(api, pr) {
  if (pr?.auto_merge) graph(api,
    "mutation($id:ID!){disablePullRequestAutoMerge(input:{pullRequestId:$id}){clientMutationId}}",
    { id: pr.node_id });
}

function branchMatches(api, { repo, mainSha }, oldHead, files) {
  if (!oldHead) return false;
  const same = Object.entries(files).every(([path, content]) => {
    const remote = api(`${repo}/contents/${path}?ref=${oldHead}`);
    return Buffer.from(remote.content, "base64").toString("utf8") === content;
  });
  return same && ["ahead", "identical"].includes(
    api(`${repo}/compare/${mainSha}...${oldHead}`).status);
}

function commitUpdate(api, snapshot, version, oldHead, state) {
  const { repo, mainSha, result } = snapshot;
  assertFresh(api, snapshot, oldHead);
  const files = { ...version.files, [statePath]: JSON.stringify(state, null, 2) + "\n" };
  // No-op on retries, including an interrupted run after the checkpoint commit.
  if (branchMatches(api, snapshot, oldHead, files)) return oldHead;
  const tree = api(`${repo}/git/trees`, "POST", {
    base_tree: api(`${repo}/git/commits/${mainSha}`).tree.sha,
    tree: Object.entries(files).map(([path, content]) => ({ path, mode: "100644", type: "blob", content })),
  });
  const parents = [...new Set([oldHead, mainSha].filter(Boolean))];
  const commit = api(`${repo}/git/commits`, "POST", {
    message: `chore(version): reconcile ${version.next}\n\nSource PRs: ${result.included.join(", ")}`,
    tree: tree.sha, parents,
  });
  assertFresh(api, snapshot, oldHead);
  if (oldHead) api(`${repo}/git/refs/heads/${branch}`, "PATCH", { sha: commit.sha, force: false });
  else api(`${repo}/git/refs`, "POST", { ref: `refs/heads/${branch}`, sha: commit.sha });
  return commit.sha;
}

function pullDetails(version, result) {
  return {
    title: `chore(version): advance to ${version.next}`,
    body: "Repository-owned alpha version checkpoint. No tags, staging, or publication.\n\n" +
      `Included source PRs: ${result.included.map(id => `#${id}`).join(", ")}\n\n` +
      "Created with GITHUB_TOKEN. If CI is waiting for approval, select **Approve workflows to run** " +
      "on this PR. Auto-merge still requires all protected-branch checks and reviews.",
  };
}

function registerDraft(api, snapshot, version, oldHead) {
  assertFresh(api, snapshot, oldHead);
  const pr = api(`${snapshot.repo}/pulls`, "POST", {
    ...pullDetails(version, snapshot.result), head: branch, base: "main", draft: true,
  });
  // Keep draft until its own positive identity is in the auditable checkpoint.
  const registeredHead = commitUpdate(api, snapshot, version, oldHead,
    recordAutomation(snapshot.result.state, pr.number));
  return { pr, oldHead: registeredHead };
}

function readyAndEnableAutoMerge(api, snapshot, version, pr, oldHead) {
  const { repo, identity, result } = snapshot;
  assertFresh(api, snapshot, oldHead);
  const latest = api(`${repo}/pulls/${pr.number}`);
  if (!owned(latest, identity) || latest.head.sha !== oldHead || latest.state !== "open") {
    throw new Error("PR changed during reconciliation; retry");
  }
  api(`${repo}/pulls/${pr.number}`, "PATCH", pullDetails(version, result));
  if (latest.draft) graph(api,
    "mutation($id:ID!){markPullRequestReadyForReview(input:{pullRequestId:$id}){clientMutationId}}",
    { id: pr.node_id });
  assertFresh(api, snapshot, oldHead);
  graph(api,
    "mutation($id:ID!){enablePullRequestAutoMerge(input:{pullRequestId:$id,mergeMethod:SQUASH}){clientMutationId}}",
    { id: pr.node_id });
}

// Explicit capabilities keep the privileged adapter testable without live mutations.
export function run(capabilities) {
  const { api, generateOpam, env, log } = capabilities;
  const snapshot = loadSnapshot(capabilities, workflowIdentity(env));
  const { result, original } = snapshot;
  let { pr } = snapshot;
  if (!result.count) {
    if (pr) throw new Error("Unexpected pending version PR with no unprocessed source merges");
    log("All merged PRs already accounted for");
    return;
  }
  let oldHead = verifyBranch(api, snapshot);
  const version = plan(original, result.count);
  version.files["rescript_linter.opam"] = generateOpam(".", version.files);
  disableAutoMerge(api, pr);
  oldHead = commitUpdate(api, snapshot, version, oldHead,
    pr ? recordAutomation(result.state, pr.number) : result.state);
  if (!pr) ({ pr, oldHead } = registerDraft(api, snapshot, version, oldHead));
  readyAndEnableAutoMerge(api, snapshot, version, pr, oldHead);
  log(`Reconciled ${result.count} source merges into #${pr.number}: ${version.next}`);
}
