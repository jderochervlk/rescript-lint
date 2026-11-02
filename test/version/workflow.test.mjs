import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const source = readFileSync(new URL("../../.github/workflows/alpha-versions.yml", import.meta.url), "utf8");

for (const [label, lineEnding] of [["LF", "\n"], ["CRLF", "\r\n"]]) {
  const fixture = source.replace(/\r?\n/g, lineEnding);
  // Git checkout line endings do not change the workflow's policy.
  const workflow = fixture.replace(/\r\n/g, "\n");

  test(`version workflow uses only the built-in token, with job-scoped write permissions (${label})`, () => {
    assert.ok(workflow.includes("GH_TOKEN: ${{ github.token }}"));
    assert.match(workflow, /\npermissions:\n  contents: read\n/);
    assert.match(workflow, /\n    permissions:\n      contents: write\n      pull-requests: write\n/);
    assert.doesNotMatch(workflow, /create-github-app-token|VERSION_APP_|VERSION_BOT_LOGIN|secrets\./);
    assert.doesNotMatch(workflow, /\b(actions|administration|id-token): write/);
  });

  test(`version workflow uses main-only push/manual events with opt-in and trusted checkout (${label})`, () => {
    assert.ok(workflow.includes("vars.VERSION_AUTOMATION_ENABLED == 'true'"));
    assert.ok(workflow.includes("github.ref == 'refs/heads/main'"));
    assert.ok(workflow.includes("github.event_name == 'push'"));
    assert.ok(workflow.includes("github.event_name == 'workflow_dispatch'"));
    assert.match(workflow, /ref: main\n          fetch-depth: 0\n          persist-credentials: false/);
    assert.match(workflow, /^  push:\n    branches: \[main\]$/m);
    assert.match(workflow, /^  workflow_dispatch:/m);
    assert.doesNotMatch(workflow, /^\s+pull_request(?:_target)?:|github\.event\.pull_request/m);
    assert.doesNotMatch(workflow, /^\s+tags:/m);
  });

  test(`version workflow serializes reconciliation without releasing or approving CI (${label})`, () => {
    assert.match(workflow, /group: alpha-version-reconciliation\n  cancel-in-progress: false/);
    assert.ok(workflow.includes("run: node scripts/version/reconcile-cli.mjs"));
    assert.doesNotMatch(workflow, /gh (run approve|pr review|workflow run)|npm (publish|stage)|stage:release|release\.yml/);
  });
}
