import assert from "node:assert/strict";
import { appendFileSync, mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import manifest from "../../npm/package.json" with { type: "json" };

const bundle = resolve("dist/compliance/bundle");
const workspace = mkdtempSync(join(tmpdir(), "rescript source rebuild "));
const run = (program, args) => {
  const result = spawnSync(program, args, { encoding: "utf8", timeout: 300000 });
  assert.equal(result.status, 0, `${program}: ${result.error ?? ""}\n${result.stdout}\n${result.stderr}`);
  return result;
};

try {
  const vendor = join(workspace, "vendor/rescript");
  mkdirSync(vendor, { recursive: true });
  run("tar", ["-xzf", join(bundle, "application.tar.gz"), "-C", workspace]);
  run("tar", ["-xzf", join(bundle, "sources/rescript.tar.gz"), "--strip-components=1", "-C", vendor]);
  // A changed library initializer proves the rebuilt executable uses the supplied source.
  appendFileSync(join(vendor, "compiler/syntax/src/res_driver.ml"), '\nlet () = prerr_endline "source-bundle-relinked"\n');
  run("opam", ["exec", "--", "dune", "build", "--root", workspace, "--profile", "release", "@install"]);
  const result = run(join(workspace, "_build/default/bin/main.exe"), ["--version"]);
  assert.equal(result.stdout.trim(), manifest.version);
  assert.match(result.stderr, /source-bundle-relinked/);
  process.stdout.write("Bundled application/ReScript sources rebuilt and relinked with a modified library.\n");
} finally {
  rmSync(workspace, { recursive: true, force: true });
}
