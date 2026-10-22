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

// Explicit capabilities keep the privileged adapter testable without live mutations.
export function run({ api, head, ancestor, readVersions, readCheckpoint, generateOpam, env, log }) {
  const repository = env.GITHUB_REPOSITORY;
  const bot = env.VERSION_BOT_LOGIN;
  if (!repository || !bot || !env.GH_TOKEN || env.VERSION_APP_TOKEN !== "true") {
    throw new Error("Requires repository, VERSION_BOT_LOGIN and explicit GitHub App installation token");
  }
  const identity = { repository, bot };
  const repo = `repos/${repository}`;
  const mainSha = api(`${repo}/git/ref/heads/main`).object.sha;
  if (head() !== mainSha) throw new Error("Checkout is not current trusted main; retry");
  const original = readVersions(".");
  plan(original);
  const checkpoint = readCheckpoint();
  if (!ancestor(checkpoint.baseline, mainSha)) throw new Error("Checkpoint baseline is not on main");
  const pulls = allPulls(api, repository);
  const merged = pulls.filter(pr => pr.merged_at && pr.base.ref === "main" &&
    ancestor(pr.merge_commit_sha, mainSha) && !ancestor(pr.merge_commit_sha, checkpoint.baseline));
  const result = reconcile(checkpoint, merged, identity);
  const pending = pulls.filter(pr => pr.state === "open" && pr.head.ref === branch &&
    pr.head.repo?.full_name === repository);
  if (pending.length > 1 || pending.some(pr => !owned(pr, identity))) throw new Error("Version branch PR ownership conflict");
  let pr = pending[0];
  if (!result.count) {
    if (pr) throw new Error("Unexpected pending version PR with no unprocessed source merges");
    log("All merged PRs already accounted for");
    return;
  }

  let oldHead;
  // A missing ref is expected only for the very first run; do not hide API errors.
  const refs = api(`${repo}/git/matching-refs/heads/${branch}`);
  const existing = refs.find(ref => ref.ref === `refs/heads/${branch}`);
  if (existing) {
    oldHead = existing.object.sha;
    const commit = api(`${repo}/commits/${oldHead}`);
    if (commit.committer?.login !== bot) throw new Error("Version branch was modified outside the App");
    const diff = api(`${repo}/compare/${mainSha}...${oldHead}`);
    const allowed = new Set([...paths, statePath]);
    if (!diff.files || diff.files.length >= 300 || diff.files.some(file => !allowed.has(file.filename))) {
      throw new Error("Unexpected files on version branch; inspect before retry");
    }
  } else if (pr) throw new Error("Pending PR branch disappeared");

  const version = plan(original, result.count);
  version.files["rescript_linter.opam"] = generateOpam(".", version.files);
  const assertFresh = () => {
    if (api(`${repo}/git/ref/heads/main`).object.sha !== mainSha) throw new Error("Main advanced; reconcile again");
    if (oldHead && api(`${repo}/git/ref/heads/${branch}`).object.sha !== oldHead) {
      throw new Error("Version branch advanced; reconcile again");
    }
  };
  const graph = (query, variables) => api("graphql", "POST", { query, variables });
  const disable = () => {
    if (pr?.auto_merge) graph("mutation($id:ID!){disablePullRequestAutoMerge(input:{pullRequestId:$id}){clientMutationId}}",
      { id: pr.node_id });
  };
  disable();
  function commitUpdate(state) {
    assertFresh();
    const files = { ...version.files, [statePath]: JSON.stringify(state, null, 2) + "\n" };
    // No-op on retries, including an interrupted run after the checkpoint commit.
    const same = oldHead && Object.entries(files).every(([path, content]) => {
      const remote = api(`${repo}/contents/${path}?ref=${oldHead}`);
      return Buffer.from(remote.content, "base64").toString("utf8") === content;
    });
    if (same && ["ahead", "identical"].includes(
      api(`${repo}/compare/${mainSha}...${oldHead}`).status)) return;
    const tree = api(`${repo}/git/trees`, "POST", {
      base_tree: api(`${repo}/git/commits/${mainSha}`).tree.sha,
      tree: Object.entries(files).map(([path, content]) => ({ path, mode: "100644", type: "blob", content })),
    });
    const parents = [...new Set([oldHead, mainSha].filter(Boolean))];
    const commit = api(`${repo}/git/commits`, "POST", {
      message: `chore(version): reconcile ${version.next}\n\nSource PRs: ${result.included.join(", ")}`,
      tree: tree.sha, parents,
    });
    assertFresh();
    if (oldHead) api(`${repo}/git/refs/heads/${branch}`, "PATCH", { sha: commit.sha, force: false });
    else api(`${repo}/git/refs`, "POST", { ref: `refs/heads/${branch}`, sha: commit.sha });
    oldHead = commit.sha;
  }
  commitUpdate(pr ? recordAutomation(result.state, pr.number) : result.state);
  if (!pr) {
    assertFresh();
    pr = api(`${repo}/pulls`, "POST", {
      title: `chore(version): advance to ${version.next}`,
      head: branch, base: "main", draft: true,
      body: "Repository-owned alpha version checkpoint. No tags, staging, or publication.\n\n" +
        `Included source PRs: ${result.included.map(id => `#${id}`).join(", ")}`,
    });
    // Keep draft until its own positive identity is in the auditable checkpoint.
    commitUpdate(recordAutomation(result.state, pr.number));
  }
  assertFresh();
  const latest = api(`${repo}/pulls/${pr.number}`);
  if (!owned(latest, identity) || latest.head.sha !== oldHead || latest.state !== "open") {
    throw new Error("PR changed during reconciliation; retry");
  }
  api(`${repo}/pulls/${pr.number}`, "PATCH", {
    title: `chore(version): advance to ${version.next}`,
    body: `Repository-owned alpha version checkpoint. No tags, staging, or publication.\n\nIncluded source PRs: ${result.included.map(id => `#${id}`).join(", ")}`,
  });
  if (latest.draft) graph("mutation($id:ID!){markPullRequestReadyForReview(input:{pullRequestId:$id}){clientMutationId}}",
    { id: pr.node_id });
  assertFresh();
  graph("mutation($id:ID!){enablePullRequestAutoMerge(input:{pullRequestId:$id,mergeMethod:SQUASH}){clientMutationId}}",
    { id: pr.node_id });
  log(`Reconciled ${result.count} source merges into #${pr.number}: ${version.next}`);
}
