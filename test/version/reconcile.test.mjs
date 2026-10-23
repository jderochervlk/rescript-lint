import { test } from "node:test";
import assert from "node:assert/strict";
import { branch, statePath, reconcile, recordAutomation, validateState } from "../../scripts/version/reconcile.mjs";
import { run } from "../../scripts/version/reconcile-run.mjs";
import { plan, readVersions } from "../../scripts/version/version.mjs";

const repository = "owner/repo";
const bot = "version-app[bot]";
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
  assert.throws(() => validateState({ ...empty, sources: [1, 1] }), /duplicate/);
  assert.throws(() => recordAutomation({ ...empty, sources: [9] }, 9), /Source/);
});

// Small stateful GitHub contract fake: exercises real adapter ordering, recovery,
// refs, draft checkpoint registration, and auto-merge without privileged access.
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
    if (route.startsWith("commits/")) return { committer: { login: bot } };
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
      for (const pr of pulls.filter(pr => pr.state === "open")) pr.head.sha = branchSha;
      result = {};
    } else if (route === "pulls" && method === "POST") {
      const number = 99 + pulls.filter(pr => pr.user.login === bot).length;
      const pr = automation(number, { state: "open", merged_at: null, draft: data.draft });
      pr.head.sha = branchSha;
      pulls.push(pr);
      result = structuredClone(pr);
    } else if (/^pulls\/[0-9]+$/.test(route)) {
      const pr = pulls.find(pr => pr.number === Number(route.split("/")[1]));
      if (method === "GET") return structuredClone(pr);
      Object.assign(pr, data);
      result = structuredClone(pr);
    } else if (path === "graphql") {
      const pending = pulls.find(pr => pr.node_id === data.variables.id);
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
    env: { GITHUB_REPOSITORY: repository, VERSION_BOT_LOGIN: bot, GH_TOKEN: "test-only", VERSION_APP_TOKEN: "true" },
    log: () => {} };
  return { run: () => run(capabilities), capabilities, pulls,
    interrupt: n => { failAfter = n; }, resume: () => { failAfter = Infinity; },
    race: () => { mutateMainOnTree = true; },
    advance: number => { mainSha = `main-${number}`; pulls.push(pull(number)); },
    snapshot: () => ({ writes, branchSha, files: branchSha && commits.get(branchSha).files, enabled }),
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

test("retry after PR creation, duplicate deliveries, rapid merges and automation merge", () => {
  const gh = github();
  gh.run();
  assert.equal(gh.pulls.filter(pr => pr.state === "open").length, 1);
  const first = gh.snapshot();
  gh.run();
  assert.equal(gh.snapshot().branchSha, first.branchSha, "retry creates no extra commit");
  gh.advance(2); gh.advance(3);
  gh.run();
  const state = JSON.parse(gh.snapshot().files[statePath]);
  assert.deepEqual(state.sources, [1, 2, 3]);
  assert.deepEqual(state.automation, [99]);
  assert.equal(plan(gh.snapshot().files).current, plan(original, 3).next);
  gh.merge();
  const merged = gh.snapshot();
  gh.run();
  assert.equal(gh.snapshot().writes, merged.writes, "automation merge does not cause another bump");
  gh.advance(4);
  gh.run();
  assert.deepEqual(JSON.parse(gh.snapshot().files[statePath]).sources, [1, 2, 3, 4]);
  assert.deepEqual(JSON.parse(gh.snapshot().files[statePath]).automation, [99, 100]);
  assert.equal(plan(gh.snapshot().files).current, plan(original, 4).next);
});

test("every accepted mutation interruption recovers without double counting", () => {
  const reference = github();
  reference.run();
  const total = reference.snapshot().writes;
  for (let step = 1; step <= total; step++) {
    const gh = github();
    gh.interrupt(step);
    assert.throws(() => gh.run(), /Interrupted/);
    gh.resume();
    gh.run();
    assert.deepEqual(JSON.parse(gh.snapshot().files[statePath]).sources, [1]);
    assert.equal(plan(gh.snapshot().files).current, plan(original, 1).next);
    assert.equal(gh.pulls.filter(pr => pr.state === "open").length, 1);
    assert.ok(gh.snapshot().enabled);
  }
});

test("freshness and credential failures stop before branch changes", () => {
  const gh = github();
  gh.race();
  assert.throws(() => gh.run(), /Main advanced/);
  assert.equal(gh.snapshot().branchSha, undefined);
  const missing = github();
  missing.capabilities.env.VERSION_APP_TOKEN = "false";
  assert.throws(() => missing.run(), /installation token/);
  assert.equal(missing.snapshot().writes, 0);
});

test("complete pagination includes rapid merges beyond the first page", () => {
  const gh = github();
  for (let number = 2; number <= 102; number++) gh.pulls.push(pull(number + 200));
  gh.run();
  assert.equal(JSON.parse(gh.snapshot().files[statePath]).sources.length, 102);
  assert.equal(plan(gh.snapshot().files).current, plan(original, 102).next);
});

test("closed-unmerged and wrong-base events make no adapter mutations", () => {
  const gh = github();
  gh.pulls.splice(0, 1, pull(1, { merged_at: null }), pull(2, {
    base: { ref: "other", repo: { full_name: repository } },
  }));
  gh.run();
  assert.equal(gh.snapshot().writes, 0);
});
