import test from "node:test";
import assert from "node:assert/strict";
import { bootstrapLedger, commitLedger, ledgerBranch, ledgerPath, readLedger } from "../../scripts/npm/alpha-staging-github-ledger.mjs";

const repository = "owner/project";
const tip = "1".repeat(40);
const nextTip = "2".repeat(40);
const empty = { schema: 1, cutoff: "0.1.0-alpha.23", releases: [] };

function apiFixture({
  rejectUpdate = false, loseUpdateResponse = false, branchExists = true,
  corruptReadback = false, invalidCommitParent = false, wrongTipAfterUpdate = false,
} = {}) {
  const calls = [];
  let state = { tip, ledger: empty, parent: undefined };
  let treeContent;
  const api = async (path, method = "GET", data) => {
    calls.push({ path, method, data });
    if (path.includes("/git/ref/heads/automation/alpha-staging-state")) {
      return { object: { sha: state.tip } };
    }
    if (path.includes("/git/commits/")) return {
      sha: state.tip, tree: { sha: "tree-old" },
      parents: state.parent ? [{ sha: state.parent }] : [],
    };
    if (path.includes("/git/trees/")) return {
      truncated: false,
      tree: [{ path: ledgerPath, type: "blob", mode: "100644" }],
    };
    if (path.includes(`/contents/${ledgerPath}`)) {
      return { encoding: "base64", content: Buffer.from(JSON.stringify(state.ledger)).toString("base64") };
    }
    if (path.endsWith("/git/blobs")) return { sha: "blob-new" };
    if (path.endsWith("/git/trees") && method === "POST") {
      treeContent = data.tree[0].content;
      return { sha: "tree-new" };
    }
    if (path.endsWith("/git/commits") && method === "POST") {
      return {
        sha: nextTip,
        parents: invalidCommitParent ? [{ sha: "wrong-parent" }]
          : (data.parents ?? []).map(sha => ({ sha })),
      };
    }
    if (path.endsWith(`/git/refs/heads/${ledgerBranch}`) && method === "PATCH") {
      if (rejectUpdate && !loseUpdateResponse) throw new Error("non-fast-forward");
      state = {
        tip: wrongTipAfterUpdate ? "3".repeat(40) : nextTip,
        ledger: globalThis.pendingLedger, parent: tip,
      };
      if (corruptReadback) state.ledger = empty;
      if (loseUpdateResponse) throw new Error("connection reset after accepted update");
      return { ref: `refs/heads/${ledgerBranch}` };
    }
    if (path.includes("/git/matching-refs/")) {
      return branchExists
        ? [{ ref: `refs/heads/${ledgerBranch}`, object: { sha: tip } }]
        : [];
    }
    if (path.endsWith("/git/refs") && method === "POST") {
      state = {
        tip: data.sha,
        ledger: JSON.parse(treeContent),
        parent: undefined,
      };
      return {};
    }
    throw new Error(`Unexpected fixture request ${method} ${path}`);
  };
  return { api, calls, state: () => state };
}

test("ledger read rejects corrupt data and exposes the observed parent", async () => {
  const fixture = apiFixture();
  const observed = await readLedger(fixture.api, repository);
  assert.equal(observed.tip, tip);
  assert.equal(observed.tree, "tree-old");
  assert.deepEqual(observed.ledger, empty);
});

test("ledger update uses a sole observed parent and a non-forced ref update", async () => {
  const fixture = apiFixture();
  const next = { ...empty, releases: [] };
  globalThis.pendingLedger = next;
  const confirmed = await commitLedger({
    api: fixture.api, repository, observed: { tip, tree: "tree-old", ledger: empty },
    next, message: "record attempt",
  });
  const commit = fixture.calls.find(call => call.path.endsWith("/git/commits") && call.method === "POST");
  const refUpdate = fixture.calls.find(call => call.method === "PATCH");
  assert.deepEqual(commit.data.parents, [tip]);
  assert.deepEqual(refUpdate.data, { sha: nextTip, force: false });
  assert.equal(confirmed.tip, nextTip);
});

test("ledger reads reject malformed ancestry, tree contents, encoding, and JSON", async () => {
  const invalid = [
    ["/git/commits/", { sha: "bad", tree: { sha: "tree-old" }, parents: [] }, /ancestry/],
    ["/git/commits/", { sha: tip, tree: { sha: "tree-old" } }, /ancestry/],
    ["/git/commits/", { sha: tip, tree: { sha: "tree-old" }, parents: [{ sha: "a" }, { sha: "b" }] }, /ancestry/],
    ["/git/trees/", { truncated: true, tree: [] }, /data file/],
    ["/git/trees/", { truncated: false }, /data file/],
    ["/git/trees/", { truncated: false, tree: [] }, /data file/],
    ["/git/trees/", { truncated: false, tree: [{ path: "extra", type: "blob", mode: "100644" }] }, /data file/],
    ["/git/trees/", { truncated: false, tree: [{ path: ledgerPath, type: "tree", mode: "100644" }] }, /data file/],
    ["/git/trees/", { truncated: false, tree: [{ path: ledgerPath, type: "blob", mode: "100755" }] }, /data file/],
    [`/contents/${ledgerPath}`, { encoding: "utf-8", content: "{}" }, /contents response/],
    [`/contents/${ledgerPath}`, { encoding: "base64" }, /contents response/],
    [`/contents/${ledgerPath}`, { encoding: "base64", content: Buffer.from("{").toString("base64") }, /corrupt/],
  ];
  for (const [matchedPath, response, error] of invalid) {
    const fixture = apiFixture();
    const api = async (path, method, data) =>
      path.includes(matchedPath) ? response : fixture.api(path, method, data);
    await assert.rejects(readLedger(api, repository), error);
  }
});

test("ledger updates fail on stale tips, competing writes, invalid parents, and unconfirmed content", async () => {
  const next = { ...empty };
  globalThis.pendingLedger = next;
  const stale = apiFixture();
  await assert.rejects(commitLedger({
    api: stale.api, repository, observed: { tip: "stale", tree: "tree-old" },
    next, message: "stale",
  }), /advanced/);

  const invalidParent = apiFixture({ invalidCommitParent: true });
  await assert.rejects(commitLedger({
    api: invalidParent.api, repository, observed: { tip, tree: "tree-old" },
    next, message: "invalid parent",
  }), /single child/);

  const competing = apiFixture({ rejectUpdate: true });
  await assert.rejects(commitLedger({
    api: competing.api, repository, observed: { tip, tree: "tree-old" },
    next, message: "competing",
  }), /not confirmed/);

  const lostResponse = apiFixture({ loseUpdateResponse: true });
  const accepted = await commitLedger({
    api: lostResponse.api, repository, observed: { tip, tree: "tree-old" },
    next, message: "accepted despite lost response",
  });
  assert.equal(accepted.tip, nextTip);

  const mismatch = apiFixture({ corruptReadback: true });
  await assert.rejects(commitLedger({
    api: mismatch.api, repository, observed: { tip, tree: "tree-old" },
    next: { ...empty, cutoff: "0.1.0-alpha.24" }, message: "wrong readback",
  }), /not confirmed exactly/);

  const wrongTip = apiFixture({ wrongTipAfterUpdate: true });
  await assert.rejects(commitLedger({
    api: wrongTip.api, repository, observed: { tip, tree: "tree-old" },
    next, message: "unexpected tip",
  }), /not confirmed exactly/);
});

test("bootstrap requires explicit authorization and never overwrites an existing ledger", async () => {
  const fixture = apiFixture();
  await assert.rejects(bootstrapLedger({ api: fixture.api, repository, cutoff: 23 }), /authorization/);
  const missing = apiFixture({ branchExists: false });
  await assert.rejects(bootstrapLedger({
    api: missing.api, repository, authorized: true, cutoff: 0,
  }), /cutoff/);
  await assert.rejects(bootstrapLedger({
    api: fixture.api, repository, authorized: true, cutoff: 23,
  }), /already exists/);
});

test("bootstrap writes one root data-only commit and rereads the confirmed ledger", async () => {
  const fixture = apiFixture({ branchExists: false });
  const initialized = await bootstrapLedger({
    api: fixture.api, repository, authorized: true, cutoff: 23,
  });
  assert.equal(initialized.tip, nextTip);
  assert.equal(initialized.ledger.cutoff, "0.1.0-alpha.23");
  const commit = fixture.calls.find(call => call.path.endsWith("/git/commits") && call.method === "POST");
  assert.deepEqual(commit.data.parents, []);
  const ref = fixture.calls.find(call => call.path.endsWith("/git/refs") && call.method === "POST");
  assert.equal(ref.data.ref, `refs/heads/${ledgerBranch}`);
});
