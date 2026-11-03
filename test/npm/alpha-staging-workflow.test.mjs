import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const release = readFileSync(new URL("../../.github/workflows/release.yml", import.meta.url), "utf8");
const npm = readFileSync(new URL("../../.github/workflows/npm.yml", import.meta.url), "utf8");

test("release workflow reconciles immutable source through one serialized trusted staging boundary", () => {
  assert.match(release, /schedule:[\s\S]*cron: "2,17,32,47 \* \* \* \*"/);
  assert.match(release, /ALPHA_STAGING_AUTOMATION_ENABLED == 'true'/);
  assert.match(release, /group: >-[\s\S]*alpha-release-staging[\s\S]*cancel-in-progress: false/);
  assert.match(release, /node scripts\/version\/alpha-release-select-cli\.mjs/);
  assert.match(release, /contents: write[\s\S]*id-token: write/);
  assert.match(release, /path: selected-source/);
  assert.match(release, /RELEASE_SOURCE_SHA:/);
  assert.match(release, /RELEASE_PULL_REQUEST:/);
  assert.match(release, /control-sha:/);
  assert.match(release, /needs\.packages\.result == 'success'/);
  assert.match(release, /github\.repository == 'jderochervlk\/rescript-lint'/);
});

test("native release checks and target discovery check out the selected immutable source", () => {
  assert.match(npm, /source-sha:[\s\S]*expected-version:/);
  assert.match(npm, /control-sha:/);
  assert.equal((npm.match(/ref: \$\{\{ inputs\.source-sha \|\| github\.sha \}\}/g) ?? []).length, 2);
  assert.match(npm, /path: \.release-control/);
  assert.match(npm, /node \.release-control\/scripts\/npm\/alpha-staging-artifacts\.mjs/);
  assert.doesNotMatch(npm, /node scripts\/npm\/alpha-staging-artifacts\.mjs/);
  assert.match(npm, /Confirm selected source version/);
  assert.match(npm, /Read shared target manifest/);
  assert.match(npm, /inputs\.retain-packages/);
  assert.match(npm, /Verify and record target artifact provenance/);
  assert.match(npm, /release-evidence\.json/);
});

test("the actual package job condition preserves stage=false when selection is skipped and rejects failed selection", () => {
  const block = release.split("  packages:\n")[1].split("\n  stage:\n")[0];
  const condition = block.match(/    if: >-\n([\s\S]*?)\n    uses:/)?.[1]
    .split("\n").map(line => line.trim()).join(" ");
  assert.ok(condition);
  const evaluate = new Function("needs", "github", "inputs", "cancelled",
    `return (${condition});`);
  const run = ({ result, selected, event, ref, stage, isCancelled = false }) =>
    evaluate(
      { select: { result, outputs: { selected } } },
      { event_name: event, ref },
      { stage },
      () => isCancelled,
    );
  assert.equal(run({ result: "skipped", event: "workflow_dispatch", ref: "refs/heads/main", stage: false }), true);
  assert.equal(run({ result: "skipped", event: "workflow_dispatch", ref: "refs/heads/feature", stage: true }), false);
  assert.equal(run({ result: "failure", event: "workflow_dispatch", ref: "refs/heads/main", stage: true }), false);
  assert.equal(run({ result: "success", selected: "false", event: "push", ref: "refs/heads/main", stage: false }), false);
  assert.equal(run({ result: "success", selected: "true", event: "push", ref: "refs/heads/main", stage: false }), true);
  assert.equal(run({ result: "success", selected: "true", event: "push", ref: "refs/heads/main", stage: false, isCancelled: true }), false);
});

test("only staging-enabled entries share the global concurrency group", () => {
  const groupExpression = release.match(/concurrency:\n  group: >-\n([\s\S]*?)\n  cancel-in-progress/)?.[1]
    .split("\n").map(line => line.trim()).join(" ")
    .replace(/^\$\{\{\s*/, "").replace(/\s*\}\}$/, "");
  assert.ok(groupExpression);
  const evaluate = new Function("inputs", "github", "vars", "format", "startsWith",
    `return (${groupExpression});`);
  const group = ({ stage, event, ref, enabled, run = "100", attempt = "1" }) =>
    evaluate(
      { stage },
      { event_name: event, ref, run_id: run, run_attempt: attempt },
      { ALPHA_STAGING_AUTOMATION_ENABLED: enabled },
      (pattern, id, number) => pattern.replace("{0}", id).replace("{1}", number),
      (value, prefix) => value.startsWith(prefix),
    );
  assert.equal(group({ stage: true, event: "workflow_dispatch", ref: "refs/heads/main" }), "alpha-release-staging");
  assert.equal(group({ event: "push", ref: "refs/tags/v0.1.0-alpha.23", enabled: "false" }), "alpha-release-staging");
  assert.equal(group({ event: "schedule", ref: "refs/heads/main", enabled: "true" }), "alpha-release-staging");
  assert.equal(group({ event: "push", ref: "refs/heads/main", enabled: "true" }), "alpha-release-staging");
  assert.equal(group({ stage: false, event: "workflow_dispatch", ref: "refs/heads/main", enabled: "true" }),
    "alpha-release-build-100-1");
  assert.equal(group({ event: "schedule", ref: "refs/heads/main", enabled: "false", run: "101" }),
    "alpha-release-build-101-1");
  assert.equal(group({ event: "push", ref: "refs/heads/main", enabled: "false", run: "102" }),
    "alpha-release-build-102-1");
});
