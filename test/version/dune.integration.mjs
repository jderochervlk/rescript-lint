import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, copyFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { readVersions, update, plan } from "../../scripts/version/version.mjs";

test("real Dune generates aligned metadata before the updater writes", t => {
  const root = mkdtempSync(join(process.cwd(), ".version-dune-test-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  copyFileSync("rescript_linter.opam.template", join(root, "rescript_linter.opam.template"));
  const files = readVersions(".");
  for (const [path, content] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
  }
  const updated = update(root, 7);
  assert.equal(plan(readVersions(root)).current, updated.next);
  assert.deepEqual(readVersions(root), updated.files);
});
