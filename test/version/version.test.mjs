import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { dirname, join } from "node:path";
import { plan, alpha, readVersions, update, releaseGuard, sourceReleaseGuard } from "../../scripts/version/version.mjs";

const original = readVersions(".");
function fixture(t) {
  const root = mkdtempSync(join(process.cwd(), ".version-test-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  for (const [path, content] of Object.entries(original)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
  }
  return root;
}

test("strict alpha increments and batch counts are deterministic and immutable", () => {
  const saved = structuredClone(original);
  const current = JSON.parse(original["npm/package.json"]).version;
  const nine = plan(Object.fromEntries(Object.entries(original).map(([path, text]) =>
    [path, text.replaceAll(current, "0.1.0-alpha.9")])));
  assert.equal(nine.next, "0.1.0-alpha.9");
  assert.equal(plan(nine.files, 1).next, "0.1.0-alpha.10");
  assert.equal(plan(nine.files, 3).next, "0.1.0-alpha.12");
  assert.equal(plan(nine.files, 0).next, nine.next);
  assert.deepEqual(original, saved);
  for (const version of ["0.1.0", "0.1.0-beta.1", "1.0.0-alpha.1", "0.1.0-alpha.01",
    "0.1.0-alpha.-1", "0.1.0-alpha.9007199254740992", "0.1.0-alpha.1\n"]) {
    assert.throws(() => alpha(version), /Unsupported/);
  }
  for (const count of [-1, NaN, 1.5, Number.MAX_SAFE_INTEGER]) assert.throws(() => plan(original, count), /count/);
});

test("all exact version-bearing locations must agree before planning", () => {
  for (const path of Object.keys(original)) {
    const corrupted = { ...original, [path]: original[path].replace("0.1.0-alpha.", "0.2.0-alpha.") };
    assert.throws(() => plan(corrupted), /Unsupported|drift/);
  }
  const duplicate = { ...original, "lib/cli/cli_command.ml": original["lib/cli/cli_command.ml"] + '\nlet version = "0.1.0-alpha.3"\n' };
  assert.throws(() => plan(duplicate), /pattern/);
  const lsp = { ...original, "test/integration/cli.t": original["test/integration/cli.t"].replace('"version":"0.1.0-alpha.', '"version":"0.2.0-alpha.') };
  assert.throws(() => plan(lsp), /LSP/);
  const latest = { ...original, "npm/package.json": original["npm/package.json"].replace('"tag": "alpha"', '"tag": "latest"') };
  assert.throws(() => plan(latest), /tag/);
});

test("dry run, validation failure and Dune failure never partially write", t => {
  const root = fixture(t);
  const fail = () => { throw new Error("Dune unavailable"); };
  const dry = update(root, 2, { dryRun: true, generate: fail });
  assert.equal(dry.count, 2);
  assert.deepEqual(readVersions(root), original);
  assert.throws(() => update(root, 1, { generate: fail }), /Dune unavailable/);
  assert.deepEqual(readVersions(root), original);
  assert.throws(() => update(root, 1, { generate: () => "unexpected" }), /metadata/);
  assert.deepEqual(readVersions(root), original);
  const path = "dune-project";
  writeFileSync(join(root, path), "unexpected");
  const corrupted = readVersions(root);
  assert.throws(() => update(root, 1, { generate: fail }), /pattern/);
  assert.deepEqual(readVersions(root), corrupted);
});

test("successful update uses generated metadata and leaves historical text alone", t => {
  const root = fixture(t);
  const path = "test/integration/cli.t";
  writeFileSync(join(root, path), original[path] + "\nHistorical example: 0.1.0-alpha.3\n");
  let generated = false;
  const result = update(root, 1, { generate: (_root, files) => {
    generated = true;
    return files["rescript_linter.opam"];
  } });
  assert.ok(generated);
  assert.deepEqual(readVersions(root), result.files);
  assert.match(result.files[path], /Historical example: 0\.1\.0-alpha\.3/);
  assert.equal(plan(result.files).current, result.next);
});

test("release guards cover tags and manual dispatch, runtime and dist-tag", () => {
  const current = plan(original).current;
  assert.equal(releaseGuard(original, { refType: "tag", refName: `v${current}`, cliVersion: current }), current);
  assert.equal(releaseGuard(original, { refType: "branch", refName: "main", cliVersion: current }), current);
  assert.throws(() => releaseGuard(original, { refType: "tag", refName: "v0.1.0", cliVersion: current }), /Tag/);
  assert.throws(() => releaseGuard(original, { cliVersion: "0.1.0" }), /CLI/);
  assert.throws(() => sourceReleaseGuard({ ...original, "npm/package.json":
    original["npm/package.json"].replace(current, "0.1.0") }, {}), /Unsupported/);
});
