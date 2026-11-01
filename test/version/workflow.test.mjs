import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const workflow = readFileSync(new URL("../../.github/workflows/alpha-versions.yml", import.meta.url), "utf8");

test("version workflow uses only the built-in token, with job-scoped write permissions", () => {
  assert.ok(workflow.includes("GH_TOKEN: ${{ github.token }}"));
  assert.match(workflow, /\npermissions:\n  contents: read\n/);
  assert.match(workflow, /\n    permissions:\n      contents: write\n      pull-requests: write\n/);
  assert.doesNotMatch(workflow, /create-github-app-token|VERSION_APP_|VERSION_BOT_LOGIN|secrets\./);
  assert.doesNotMatch(workflow, /\b(actions|administration|id-token): write/);
});

test("version workflow retains opt-in, merged-main guard and trusted checkout", () => {
  assert.ok(workflow.includes("vars.VERSION_AUTOMATION_ENABLED == 'true'"));
  assert.ok(workflow.includes("github.ref == 'refs/heads/main'"));
  assert.ok(workflow.includes("github.event.pull_request.merged == true"));
  assert.ok(workflow.includes("github.event.pull_request.base.ref == 'main'"));
  assert.match(workflow, /ref: main\n          fetch-depth: 0\n          persist-credentials: false/);
  assert.match(workflow, /pull_request_target:\n    types: \[closed\]\n    branches: \[main\]/);
  assert.match(workflow, /workflow_dispatch:/);
});

test("version workflow serializes reconciliation without releasing or approving CI", () => {
  assert.match(workflow, /group: alpha-version-reconciliation\n  cancel-in-progress: false/);
  assert.ok(workflow.includes("run: node scripts/version/reconcile-cli.mjs"));
  assert.doesNotMatch(workflow, /gh (run approve|pr review|workflow run)|npm (publish|stage)|stage:release|release\.yml/);
});
