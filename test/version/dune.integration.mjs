import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { readVersions, update, plan } from "../../scripts/version/version.mjs";

function fixture(t, template) {
  const root = mkdtempSync(join(process.cwd(), ".version-dune-test-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  writeFileSync(join(root, "rescript_linter.opam.template"), template);
  const files = readVersions(".");
  for (const [path, content] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
  }
  return root;
}

const template = readFileSync("rescript_linter.opam.template", "utf8").replace(/\r\n/g, "\n");

for (const [name, content] of [["LF", template], ["CRLF", template.replace(/\n/g, "\r\n")]]) {
  test(`real Dune generates aligned metadata from ${name} template before writes`, t => {
    const root = fixture(t, content);
    const updated = update(root, 7);
    assert.equal(plan(readVersions(root)).current, updated.next);
    assert.deepEqual(readVersions(root), updated.files);
  });
}

test("real Dune rejects substantive template drift without writing source files", t => {
  const root = fixture(t, template + 'x-version-regression: "unexpected"\n');
  const original = readVersions(root);
  assert.throws(() => update(root, 7), /Dune generated unexpected metadata/);
  assert.deepEqual(readVersions(root), original);
});
