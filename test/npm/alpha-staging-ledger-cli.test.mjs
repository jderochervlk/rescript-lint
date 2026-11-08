import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

const cli = fileURLToPath(new URL("../../scripts/npm/alpha-staging-ledger-cli.mjs", import.meta.url));
const root = mkdtempSync(join(tmpdir(), "alpha-ledger-cli-"));
const stateFile = join(root, "state.json");
const preload = `
  import fs from "node:fs";
  import child from "node:child_process";
  import { syncBuiltinESMExports } from "node:module";
  const file = process.env.FIXTURE_STATE_FILE;
  let state = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8"))
    : { tip: undefined, ledger: { schema: 1, cutoff: "0.1.0-alpha.22", releases: [] }, parent: undefined };
  let content;
  child.spawnSync = (_command, args, options = {}) => {
    if (process.env.FIXTURE_API_FAILURE === "true") {
      return { status: 1, stderr: "fixture API failure" };
    }
    const path = args[1];
    const method = args[args.indexOf("--method") + 1];
    const body = options.input ? JSON.parse(options.input) : undefined;
    let value;
    if (path.includes("/git/matching-refs/")) {
      value = state.tip ? [{ ref: "refs/heads/automation/alpha-staging-state", object: { sha: state.tip } }] : [];
    } else if (path.includes("/git/ref/heads/")) {
      value = { object: { sha: state.tip } };
    } else if (path.includes("/git/commits/")) {
      value = { sha: state.tip, tree: { sha: "tree" }, parents: state.parent ? [{ sha: state.parent }] : [] };
    } else if (path.includes("/git/trees/") && method === "GET") {
      value = { truncated: false, tree: [{ path: "alpha-staging-ledger.json", mode: "100644", type: "blob" }] };
    } else if (path.endsWith("/git/trees") && method === "POST") {
      content = body.tree[0].content;
      value = { sha: "tree-new" };
    } else if (path.endsWith("/git/commits") && method === "POST") {
      value = { sha: "2".repeat(40), parents: (body.parents ?? []).map(sha => ({ sha })) };
    } else if (path.endsWith("/git/refs") && method === "POST") {
      state = { tip: body.sha, ledger: JSON.parse(content), parent: undefined };
      fs.writeFileSync(file, JSON.stringify(state));
      value = { ref: body.ref };
    } else if (path.includes("/contents/alpha-staging-ledger.json")) {
      value = { encoding: "base64", content: Buffer.from(JSON.stringify(state.ledger)).toString("base64") };
    } else {
      return { status: 1, stderr: "unexpected fixture API request" };
    }
    return { status: 0, stdout: JSON.stringify(value) };
  };
  syncBuiltinESMExports();
`;

function run(args, extra = {}) {
  return spawnSync(process.execPath, [
    "--import", `data:text/javascript,${encodeURIComponent(preload)}`, cli, ...args,
  ], {
    encoding: "utf8",
    env: {
      ...process.env, GITHUB_REPOSITORY: "jderochervlk/rescript-lint",
      // Model an operator session independently of the host running these tests.
      GITHUB_ACTIONS: "false", GH_TOKEN: "fixture-token",
      FIXTURE_STATE_FILE: stateFile, ...extra,
    },
  });
}

test("operator ledger inspect reads the durable data without mutation", () => {
  writeFileSync(stateFile, JSON.stringify({
    tip: "1".repeat(40), ledger: { schema: 1, cutoff: "0.1.0-alpha.22", releases: [] },
  }));
  const inspected = run(["inspect"]);
  assert.equal(inspected.status, 0, inspected.stderr);
  const output = JSON.parse(inspected.stdout);
  assert.equal(output.ledger.cutoff, "0.1.0-alpha.22");
  assert.equal(output.ledger.releases.length, 0);
});

test("operator bootstrap requires explicit confirmation and initializes only missing state", () => {
  rmSync(stateFile, { force: true });
  const unauthorized = run(["bootstrap", "--cutoff=22"]);
  assert.notEqual(unauthorized.status, 0);
  assert.match(unauthorized.stderr, /Usage/);
  const initialized = run(["bootstrap", "--confirm-bootstrap", "--cutoff=22"]);
  assert.equal(initialized.status, 0, initialized.stderr);
  assert.match(initialized.stdout, /Initialized/);
  assert.equal(JSON.parse(readFileSync(stateFile, "utf8")).ledger.cutoff, "0.1.0-alpha.22");
  const duplicate = run(["bootstrap", "--confirm-bootstrap", "--cutoff=22"]);
  assert.notEqual(duplicate.status, 0);
  assert.match(duplicate.stderr, /already exists/);
});

test("operator commands reject malformed arguments and unsafe cutoff values", () => {
  for (const args of [
    ["unknown"],
    ["inspect", "extra"],
    ["bootstrap", "wrong-confirmation", "--cutoff=22"],
    ["bootstrap", "--confirm-bootstrap", "--cutoff"],
    ["bootstrap", "--confirm-bootstrap", "--cutoff=not-a-number"],
    ["bootstrap", "--confirm-bootstrap", "--cutoff=0"],
  ]) {
    const rejected = run(args);
    assert.notEqual(rejected.status, 0);
    assert.match(rejected.stderr, /Usage|cutoff/);
  }
});

test("operator bootstrap cannot execute from Actions or without authenticated context", () => {
  const originalState = JSON.stringify({
    tip: "1".repeat(40), ledger: { schema: 1, cutoff: "0.1.0-alpha.22", releases: [] },
  });
  writeFileSync(stateFile, originalState);
  const actions = run(
    ["bootstrap", "--confirm-bootstrap", "--cutoff=22"],
    { GITHUB_ACTIONS: "true" },
  );
  assert.notEqual(actions.status, 0);
  assert.match(actions.stderr, /operator-only/);
  assert.equal(readFileSync(stateFile, "utf8"), originalState);
  const unauthenticated = run(["inspect"], { GH_TOKEN: "", GITHUB_REPOSITORY: "" });
  assert.notEqual(unauthenticated.status, 0);
  assert.match(unauthenticated.stderr, /Set GITHUB_REPOSITORY and GH_TOKEN/);
  const missingRepository = run(["inspect"], { GITHUB_REPOSITORY: "", GH_TOKEN: "fixture" });
  assert.notEqual(missingRepository.status, 0);
  assert.match(missingRepository.stderr, /Set GITHUB_REPOSITORY and GH_TOKEN/);
  const failedApi = run(["inspect"], { FIXTURE_API_FAILURE: "true" });
  assert.notEqual(failedApi.status, 0);
  assert.match(failedApi.stderr, /fixture API failure/);
});

test.after(() => rmSync(root, { recursive: true, force: true }));
