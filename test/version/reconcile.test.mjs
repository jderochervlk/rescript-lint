import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { branch, statePath, ownedCommit, reconcile, recordAutomation, validateState } from "../../scripts/version/reconcile.mjs";
import { run } from "../../scripts/version/reconcile-run.mjs";
import { plan, readVersions } from "../../scripts/version/version.mjs";

const repository = "owner/repo";
const bot = "github-actions[bot]";
const identity = { repository, bot };
const baseline = "0".repeat(40);
const empty = { schema: 1, baseline, sources: [], automation: [] };
const original = readVersions(".");
function pull(number, overrides = {}) {
  return { number, node_id: `PR_${number}`, state: "closed", merged_at: "2026-10-22T12:00:00Z",
    merge_commit_sha: `merge-${number}`, user: { login: "human" }, draft: false,
    base: { ref: "main", repo: { full_name: repository } },
    head: { ref: `feature-${number}`, repo: { full_name: repository } }, ...overrides };
}
function automation(number, overrides = {}) {
  return pull(number, { user: { login: bot },
    head: { ref: branch, repo: { full_name: repository } }, ...overrides });
}

function automationCommit({ author = bot, committer = bot, verified = true, reason = "valid" } = {}) {
  return { author: { login: author }, committer: { login: committer },
    commit: { verification: { verified, reason } } };
}

test("commit ownership accepts bot authors with bot or verified GitHub committers only", () => {
  assert.equal(ownedCommit(automationCommit(), identity), true);
  assert.equal(ownedCommit(automationCommit({ committer: "web-flow" }), identity), true);
  for (const commit of [
    null, {}, automationCommit({ author: "human" }), automationCommit({ committer: "other[bot]" }),
    automationCommit({ author: "human", committer: "web-flow" }),
    automationCommit({ committer: "web-flow", verified: false }),
    automationCommit({ committer: "web-flow", reason: "unsigned" }),
    { author: { login: bot }, committer: { login: "web-flow" } },
  ]) {
    assert.equal(ownedCommit(commit, identity), false);
  }
});

test("ordinary merges include bots/docs; closed-unmerged and wrong bases do nothing", () => {
  const source = [pull(1), pull(2, { user: { login: bot } }), pull(3, { merged_at: null }),
    pull(4, { base: { ref: "other", repo: { full_name: repository } } }), pull(1)];
  const result = reconcile(empty, source, identity);
  assert.equal(result.count, 2);
  assert.deepEqual(result.included, [1, 2]);
  assert.equal(reconcile(result.state, source, identity).count, 0);
  assert.deepEqual(empty.sources, []);
});

test("only registered exact automation identity is excluded; spoofing fails closed", () => {
  const state = recordAutomation(empty, 9);
  assert.equal(reconcile(state, [automation(9)], identity).count, 0);
  assert.throws(() => reconcile(empty, [automation(9)], identity), /Unregistered/);
  assert.throws(() => reconcile(state, [pull(9)], identity), /identity/);
  for (const head of [
    { ref: "other", repo: { full_name: repository } },
    { ref: branch, repo: { full_name: "someone/fork" } },
  ]) {
    assert.throws(() => reconcile(state, [automation(9, { head })], identity), /identity/);
  }
  assert.throws(() => validateState({ ...empty, sources: [1, 1] }), /duplicate/);
  assert.throws(() => recordAutomation({ ...empty, sources: [9] }, 9), /Source/);
});

// One stateful GitHub contract fake keeps refs, PR metadata and accepted writes
// together so interruption/lag scenarios cannot drift between separate mocks.
// Local mutation models this remote boundary without privileged access.
function github() {
  let mainSha = "main-1";
  let files = structuredClone(original);
  let checkpoint = structuredClone(empty);
  let branchSha;
  const commits = new Map();
  const trees = new Map();
  let sequence = 0;
  const pulls = [pull(1)];
  let writes = 0;
  let failAfter = Infinity;
  let mutateMainOnTree = false;
  let enabled = false;
  let canCreatePulls = true;
  // Matches GitHub's actual GITHUB_TOKEN commit metadata, not just bot self-commits.
  let commitDetails = automationCommit({ committer: "web-flow" });
  let lagHeadReads = 0;
  const pauses = [];
  let pauseEffect = () => {};
  function pullSnapshot(pr) {
    if (pr.head.sha !== branchSha) {
      if (lagHeadReads > 0) lagHeadReads--;
      else pr.head.sha = branchSha;
    }
    return structuredClone(pr);
  }
  function api(path, method = "GET", data) {
    const route = path.replace(`repos/${repository}/`, "");
    let result;
    if (route === "git/ref/heads/main") return { object: { sha: mainSha } };
    if (route === `git/ref/heads/${branch}`) return { object: { sha: branchSha } };
    if (route.startsWith("pulls?")) {
      const page = Number(new URLSearchParams(route.split("?")[1]).get("page"));
      return structuredClone(pulls.slice((page - 1) * 100, page * 100));
    }
    if (route.startsWith("git/matching-refs")) return branchSha ? [{ ref: `refs/heads/${branch}`, object: { sha: branchSha } }] : [];
    if (route.startsWith("commits/")) return structuredClone(commitDetails);
    if (route.startsWith("compare/")) return { files: Object.keys(commits.get(branchSha).files).map(filename => ({ filename })), status: "ahead" };
    if (route.startsWith("contents/")) {
      const path = route.slice("contents/".length).split("?")[0];
      return { content: Buffer.from(commits.get(branchSha).files[path]).toString("base64") };
    }
    if (route.startsWith("git/commits/") && method === "GET") return { tree: { sha: "main-tree" } };
    if (route === "git/trees") {
      const sha = `tree-${++sequence}`;
      trees.set(sha, Object.fromEntries(data.tree.map(entry => [entry.path, entry.content])));
      if (mutateMainOnTree) { mainSha = "raced-main"; mutateMainOnTree = false; }
      result = { sha };
    } else if (route === "git/commits") {
      const sha = `commit-${++sequence}`;
      commits.set(sha, { files: trees.get(data.tree), parents: data.parents });
      result = { sha };
    } else if (route === "git/refs" || route === `git/refs/heads/${branch}`) {
      assert.notEqual(data.force, true);
      if (branchSha) assert.ok(commits.get(data.sha).parents.includes(branchSha), "updates preserve branch history");
      branchSha = data.sha;
      if (lagHeadReads === 0) {
        for (const pr of pulls.filter(pr => pr.state === "open")) pr.head.sha = branchSha;
      }
      result = {};
    } else if (route === "pulls" && method === "POST") {
      if (!canCreatePulls) throw new Error("GitHub Actions is not permitted to create or approve pull requests");
      const number = 99 + pulls.filter(pr => pr.user.login === bot).length;
      const pr = automation(number, { state: "open", merged_at: null, draft: data.draft });
      pr.head.sha = branchSha;
      pulls.push(pr);
      result = structuredClone(pr);
    } else if (/^pulls\/[0-9]+$/.test(route)) {
      const pr = pulls.find(pr => pr.number === Number(route.split("/")[1]));
      if (method === "GET") return pullSnapshot(pr);
      Object.assign(pr, data);
      result = structuredClone(pr);
    } else if (path === "graphql") {
      const pending = pulls.find(pr => pr.node_id === data.variables.id);
      if (data.query.includes("markPullRequestReady") || data.query.includes("enablePullRequestAutoMerge")) {
        assert.equal(pending.head.sha, branchSha, "never ready or auto-merge a stale PR head");
        const state = JSON.parse(commits.get(branchSha).files[statePath]);
        assert.ok(state.automation.includes(pending.number), "never ready an unregistered draft");
      }
      if (data.query.includes("markPullRequestReady")) pending.draft = false;
      if (data.query.includes("disablePullRequestAutoMerge")) enabled = false;
      if (data.query.includes("enablePullRequestAutoMerge")) {
        const state = JSON.parse(commits.get(branchSha).files[statePath]);
        assert.ok(state.automation.includes(pending.number), "never auto-merge an unregistered draft");
        enabled = true;
        pending.auto_merge = {};
      }
      result = {};
    } else throw new Error(`Unexpected API ${method} ${route}`);
    writes++;
    if (writes === failAfter) throw new Error("Interrupted after accepted mutation");
    return result;
  }
  const capabilities = { api, head: () => mainSha,
    ancestor: (older, newer) => older === baseline || older === newer ||
      (newer !== baseline && older.startsWith("merge-")),
    readVersions: () => structuredClone(files), readCheckpoint: () => structuredClone(checkpoint),
    generateOpam: (_root, files) => files["rescript_linter.opam"],
    pause: async delay => { pauses.push(delay); pauseEffect(); },
    env: { GITHUB_REPOSITORY: repository, GH_TOKEN: "test-only",
      GITHUB_ACTIONS: "true", GITHUB_REF: "refs/heads/main" },
    log: () => {} };
  return { run: () => run(capabilities), capabilities, pulls,
    interrupt: n => { failAfter = n; }, resume: () => { failAfter = Infinity; },
    race: () => { mutateMainOnTree = true; },
    allowPullCreation: allowed => { canCreatePulls = allowed; },
    changeCommitter: login => { commitDetails = { ...commitDetails, committer: { login } }; },
    changeCommit: details => { commitDetails = details; },
    lagHead: reads => { lagHeadReads = reads; },
    duringPause: effect => { pauseEffect = effect; },
    changeBranch: () => {
      commits.set("raced-branch", structuredClone(commits.get(branchSha)));
      branchSha = "raced-branch";
    },
    advance: number => { mainSha = `main-${number}`; pulls.push(pull(number)); },
    advanceWithoutPull: () => { mainSha = "main-direct"; },
    snapshot: () => ({ writes, branchSha, files: branchSha && commits.get(branchSha).files,
      enabled, pauses: [...pauses] }),
    merge: () => {
      const pending = pulls.find(pr => pr.state === "open");
      pending.state = "closed"; pending.merged_at = "2026-10-22T13:00:00Z"; pending.merge_commit_sha = "merge-99";
      const updated = commits.get(branchSha).files;
      checkpoint = JSON.parse(updated[statePath]);
      files = Object.fromEntries(Object.keys(original).map(path => [path, updated[path]]));
      mainSha = "main-merged";
    },
  };
}

test("PR head lag settles before readiness without extra version commits", async () => {
  const gh = github();
  gh.lagHead(2);
  await gh.run();
  assert.deepEqual(gh.snapshot().pauses, [500, 1000]);
  assert.equal(gh.pulls.filter(pr => pr.state === "open").length, 1);
  assert.equal(gh.pulls.find(pr => pr.state === "open").draft, false);
  assert.ok(gh.snapshot().enabled);
  assert.deepEqual(JSON.parse(gh.snapshot().files[statePath]).automation, [99]);
});

test("permanent head lag leaves a registered signed draft that retries without new commits", async () => {
  const gh = github();
  gh.lagHead(Infinity);
  await assert.rejects(gh.run(), /head did not synchronize/);
  const blocked = gh.snapshot();
  assert.deepEqual(blocked.pauses, [500, 1000, 2000, 4000, 8000]);
  assert.equal(blocked.enabled, false);
  assert.equal(gh.pulls.find(pr => pr.state === "open").draft, true);
  assert.deepEqual(JSON.parse(blocked.files[statePath]).automation, [99]);
  gh.lagHead(0);
  await gh.run();
  assert.equal(gh.snapshot().branchSha, blocked.branchSha);
  assert.equal(gh.pulls.filter(pr => pr.state === "open").length, 1);
  assert.deepEqual(JSON.parse(gh.snapshot().files[statePath]).sources, [1]);
  assert.ok(gh.snapshot().enabled);
});

test("main, branch, ownership and closed-state changes during waits stop further mutations", async () => {
  for (const [mutate, message] of [
    [gh => gh.advance(2), /Main advanced/],
    [gh => gh.changeBranch(), /Version branch advanced/],
    [gh => { gh.pulls.find(pr => pr.number === 99).state = "closed"; }, /identity or state changed/],
    [gh => { gh.pulls.find(pr => pr.number === 99).user.login = "human"; }, /identity or state changed/],
  ]) {
    const gh = github();
    gh.lagHead(1);
    let writesAtPause;
    gh.duringPause(() => { writesAtPause = gh.snapshot().writes; mutate(gh); });
    await assert.rejects(gh.run(), message);
    assert.equal(gh.snapshot().writes, writesAtPause);
    assert.deepEqual(gh.snapshot().pauses, [500]);
    assert.equal(gh.snapshot().enabled, false);
    assert.equal(gh.pulls.find(pr => pr.number === 99).draft, true);
  }
});

test("PR read failures propagate without head-synchronization retries", async () => {
  const gh = github();
  const originalApi = gh.capabilities.api;
  const failure = new Error("fixture PR API failure");
  gh.capabilities.api = (path, method = "GET", data) => {
    if (path === `repos/${repository}/pulls/99` && method === "GET") throw failure;
    return originalApi(path, method, data);
  };
  await assert.rejects(gh.run(), error => error === failure);
  assert.deepEqual(gh.snapshot().pauses, []);
  assert.equal(gh.snapshot().enabled, false);
  assert.equal(gh.pulls.find(pr => pr.number === 99).draft, true);
});

test("refs are checked again after a synchronized read and before readiness mutations", async () => {
  const gh = github();
  const originalApi = gh.capabilities.api;
  gh.capabilities.api = (path, method = "GET", data) => {
    const result = originalApi(path, method, data);
    if (path === `repos/${repository}/pulls/99` && method === "GET") queueMicrotask(() => gh.advance(2));
    return result;
  };
  await assert.rejects(gh.run(), /Main advanced/);
  assert.deepEqual(gh.snapshot().pauses, []);
  assert.equal(gh.snapshot().enabled, false);
  assert.equal(gh.pulls.find(pr => pr.number === 99).draft, true);
});

test("refs are checked between the PR metadata update and readiness", async () => {
  const gh = github();
  const originalApi = gh.capabilities.api;
  gh.capabilities.api = (path, method = "GET", data) => {
    const result = originalApi(path, method, data);
    if (path === `repos/${repository}/pulls/99` && method === "PATCH") gh.advance(2);
    return result;
  };
  await assert.rejects(gh.run(), /Main advanced/);
  assert.equal(gh.snapshot().enabled, false);
  assert.equal(gh.pulls.find(pr => pr.number === 99).draft, true);
});

test("built-in token needs no App settings and requests auto-merge without bypassing CI", async () => {
  const gh = github();
  assert.deepEqual(Object.keys(gh.capabilities.env).toSorted(),
    ["GITHUB_ACTIONS", "GITHUB_REF", "GITHUB_REPOSITORY", "GH_TOKEN"].toSorted());
  await gh.run();
  const pr = gh.pulls.find(pr => pr.state === "open");
  assert.equal(pr.user.login, "github-actions[bot]");
  assert.equal(pr.draft, false);
  assert.match(pr.body, /Approve workflows to run/);
  assert.ok(gh.snapshot().enabled);
  assert.equal(pr.merged_at, null, "requesting auto-merge is not a merge or workflow approval");
});

test("PR-creation policy denial preserves main and can retry without double counting", async () => {
  const gh = github();
  gh.allowPullCreation(false);
  await assert.rejects(gh.run(), /not permitted to create/);
  assert.ok(gh.snapshot().branchSha);
  assert.equal(gh.capabilities.head(), "main-1");
  assert.deepEqual(gh.capabilities.readCheckpoint(), empty);
  assert.equal(gh.pulls.filter(pr => pr.state === "open").length, 0);
  gh.allowPullCreation(true);
  await gh.run();
  assert.equal(gh.pulls.filter(pr => pr.state === "open").length, 1);
  assert.deepEqual(JSON.parse(gh.snapshot().files[statePath]).sources, [1]);
  assert.equal(plan(gh.snapshot().files).current, plan(original, 1).next);
});

test("a version branch written by another identity fails before further mutations", async () => {
  const gh = github();
  await gh.run();
  const writes = gh.snapshot().writes;
  gh.changeCommitter("other[bot]");
  await assert.rejects(gh.run(), /not owned by GitHub Actions/);
  assert.equal(gh.snapshot().writes, writes);
});

test("signed-commit recovery rejects other authors and invalid GitHub verification", async () => {
  for (const commit of [
    automationCommit({ author: "human", committer: "web-flow" }),
    automationCommit({ committer: "web-flow", verified: false }),
    automationCommit({ committer: "web-flow", reason: "unsigned" }),
  ]) {
    const gh = github();
    await gh.run();
    const writes = gh.snapshot().writes;
    gh.changeCommit(commit);
    await assert.rejects(gh.run(), /not owned by GitHub Actions/);
    assert.equal(gh.snapshot().writes, writes);
  }
});

test("retry after PR creation, duplicate deliveries, rapid merges and automation merge", async () => {
  const gh = github();
  await gh.run();
  assert.equal(gh.pulls.filter(pr => pr.state === "open").length, 1);
  const first = gh.snapshot();
  await gh.run();
  assert.equal(gh.snapshot().branchSha, first.branchSha, "retry creates no extra commit");
  gh.advance(2); gh.advance(3);
  await gh.run();
  const state = JSON.parse(gh.snapshot().files[statePath]);
  assert.deepEqual(state.sources, [1, 2, 3]);
  assert.deepEqual(state.automation, [99]);
  assert.equal(plan(gh.snapshot().files).current, plan(original, 3).next);
  gh.merge();
  const merged = gh.snapshot();
  await gh.run();
  assert.equal(gh.snapshot().writes, merged.writes, "automation merge does not cause another bump");
  gh.advance(4);
  await gh.run();
  assert.deepEqual(JSON.parse(gh.snapshot().files[statePath]).sources, [1, 2, 3, 4]);
  assert.deepEqual(JSON.parse(gh.snapshot().files[statePath]).automation, [99, 100]);
  assert.equal(plan(gh.snapshot().files).current, plan(original, 4).next);
});

test("a direct main advance without another merged source PR does not bump the version", async () => {
  const gh = github();
  await gh.run();
  gh.merge();
  const before = gh.snapshot();
  const checkpoint = gh.capabilities.readCheckpoint();
  gh.advanceWithoutPull();
  await gh.run();
  assert.equal(gh.snapshot().writes, before.writes);
  assert.equal(gh.snapshot().branchSha, before.branchSha);
  assert.equal(gh.pulls.filter(pr => pr.state === "open").length, 0);
  assert.deepEqual(gh.capabilities.readCheckpoint(), checkpoint);
  assert.equal(plan(gh.capabilities.readVersions()).current, plan(original, 1).next);
});

test("every accepted mutation interruption recovers without double counting", async () => {
  const reference = github();
  await reference.run();
  const total = reference.snapshot().writes;
  for (let step = 1; step <= total; step++) {
    const gh = github();
    gh.interrupt(step);
    await assert.rejects(gh.run(), /Interrupted/);
    gh.resume();
    await gh.run();
    assert.deepEqual(JSON.parse(gh.snapshot().files[statePath]).sources, [1]);
    assert.equal(plan(gh.snapshot().files).current, plan(original, 1).next);
    assert.equal(gh.pulls.filter(pr => pr.state === "open").length, 1);
    assert.ok(gh.snapshot().enabled);
  }
});

test("freshness and credential failures stop before branch changes", async () => {
  const gh = github();
  gh.race();
  await assert.rejects(gh.run(), /Main advanced/);
  assert.equal(gh.snapshot().branchSha, undefined);
  for (const overrides of [
    { GH_TOKEN: undefined }, { GITHUB_REPOSITORY: undefined },
    { GITHUB_ACTIONS: "false" }, { GITHUB_REF: "refs/heads/feature" },
  ]) {
    const missing = github();
    Object.assign(missing.capabilities.env, overrides);
    await assert.rejects(missing.run(), /GITHUB_TOKEN in GitHub Actions on trusted main/);
    assert.equal(missing.snapshot().writes, 0);
  }
});

test("complete pagination includes rapid merges beyond the first page", async () => {
  const gh = github();
  for (let number = 2; number <= 102; number++) gh.pulls.push(pull(number + 200));
  await gh.run();
  assert.equal(JSON.parse(gh.snapshot().files[statePath]).sources.length, 102);
  assert.equal(plan(gh.snapshot().files).current, plan(original, 102).next);
});

test("closed-unmerged and wrong-base events make no adapter mutations", async () => {
  const gh = github();
  gh.pulls.splice(0, 1, pull(1, { merged_at: null }), pull(2, {
    base: { ref: "other", repo: { full_name: repository } },
  }));
  await gh.run();
  assert.equal(gh.snapshot().writes, 0);
});

test("CLI awaits orchestration and reports rejected context checks without an unhandled rejection", () => {
  const script = fileURLToPath(new URL("../../scripts/version/reconcile-cli.mjs", import.meta.url));
  const result = spawnSync(process.execPath, [script], {
    env: { ...process.env, GH_TOKEN: "", GITHUB_REPOSITORY: repository,
      GITHUB_ACTIONS: "true", GITHUB_REF: "refs/heads/main" },
    encoding: "utf8",
  });
  assert.equal(result.status, 1);
  assert.equal(result.stdout, "");
  assert.equal(result.stderr.trim(), "Requires GITHUB_TOKEN in GitHub Actions on trusted main");
});
