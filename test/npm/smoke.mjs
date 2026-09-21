import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { delimiter, dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import launcher from "../../npm/lib/launcher.cjs";
import platform from "../../npm/lib/platform.cjs";
import compliance from "../../scripts/npm/compliance.cjs";

const require = createRequire(import.meta.url);
const manifest = require("../../npm/package.json");
const detected = launcher.detectHost(process);
assert.equal(detected._tag, "Host");
const selected = platform.selectTarget(detected.host);
assert.equal(selected._tag, "Target");
const target = selected.target;
const artifacts = resolve("dist/npm", target.id);
const directory = mkdtempSync(join(tmpdir(), "rescript npm smoke "));

function tarball(name) {
  return join(artifacts, `${name.replace("@", "").replace("/", "-")}-${manifest.version}.tgz`);
}

function install() {
  assert.ok(process.env.npm_execpath, "Run npm run test:package.");
  writeFileSync(join(directory, "package.json"), JSON.stringify({ name: "smoke", private: true }));
  const result = spawnSync(process.execPath, [process.env.npm_execpath, "install",
    "--offline", "--ignore-scripts", "--no-audit", "--no-fund",
    tarball(platform.packageName(target)), tarball(manifest.name)], { cwd: directory, encoding: "utf8" });
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
}

function cleanEnvironment() {
  const paths = process.platform === "win32"
    ? [dirname(process.execPath), join(process.env.SystemRoot, "System32"), process.env.SystemRoot]
    : [dirname(process.execPath), "/usr/bin", "/bin"];
  const env = Object.fromEntries(Object.entries(process.env)
    .filter(([key]) => !["path", "node_path", "node_options"].includes(key.toLowerCase())));
  return { ...env, PATH: paths.join(delimiter) };
}

function cli(args) {
  const bin = join(directory, "node_modules", ".bin", "rescript-lint");
  // cmd.exe is used only for a fixed shim command; file arguments stay with Node.
  if (process.platform === "win32") {
    const shim = spawnSync("cmd.exe", ["/d", "/s", "/c", '"node_modules\\.bin\\rescript-lint.cmd --version"'],
      { cwd: directory, env: cleanEnvironment(), encoding: "utf8", windowsVerbatimArguments: true });
    assert.equal(shim.status, 0, shim.stderr);
    assert.equal(shim.stdout.trim(), manifest.version);
    return spawnSync(process.execPath,
      [join(directory, "node_modules", manifest.name, "bin/rescript-lint.cjs"), ...args],
      { cwd: directory, env: cleanEnvironment(), encoding: "utf8" });
  }
  return spawnSync(bin, args, { cwd: directory, env: cleanEnvironment(), encoding: "utf8" });
}

function checkContracts() {
  const version = cli(["--version"]);
  assert.equal(version.status, 0, version.stderr);
  assert.equal(version.stdout.trim(), manifest.version);
  const help = cli(["--help"]);
  assert.equal(help.status, 0, help.stderr);
  assert.match(help.stdout, /Usage: rescript-lint/);
  writeFileSync(join(directory, "clean file.res"), "let value = 1\n");
  writeFileSync(join(directory, "lint file.res"), "Console.log(1)\n");
  writeFileSync(join(directory, "broken.res"), "let value =\n");
  assert.equal(cli(["--", "clean file.res"]).status, 0);
  const finding = cli(["lint file.res"]);
  assert.equal(finding.status, 1, finding.stderr);
  assert.match(finding.stdout, /error \[no-console\]/);
  assert.equal(cli(["broken.res"]).status, 2);
  assert.equal(cli(["missing.res"]).status, 2);
  assert.equal(cli([]).status, 2);
  const installed = JSON.parse(readFileSync(join(directory, "node_modules", manifest.name, "package.json"), "utf8"));
  assert.equal(installed.optionalDependencies[platform.packageName(target)], manifest.version);
}

function checkContents() {
  const main = join(directory, "node_modules", manifest.name);
  const native = join(directory, "node_modules", platform.packageName(target));
  assert.deepEqual(readdirSync(main).sort(),
    ["DISTRIBUTION.md", "LICENSE", "README.md", "bin", "lib", "package.json", "targets.json"]);
  assert.deepEqual(readdirSync(native).sort(), ["DISTRIBUTION.md", "LICENSE", "README.md", "bin", "package.json", "third-party"]);
  assert.equal(compliance.validateBundle(resolve("."), join(native, "bin", target.binary), join(native, "third-party")), undefined);
  assert.deepEqual(readdirSync(join(main, "bin")), ["rescript-lint.cjs"]);
  assert.deepEqual(readdirSync(join(main, "lib")).sort(), ["launcher.cjs", "platform.cjs"]);
  assert.deepEqual(readdirSync(join(native, "bin")), [target.binary]);
  const license = readFileSync(new URL("../../LICENSE", import.meta.url), "utf8");
  const readme = readFileSync(new URL("../../npm/README.md", import.meta.url), "utf8");
  for (const packageDirectory of [main, native]) {
    assert.equal(readFileSync(join(packageDirectory, "LICENSE"), "utf8"), license);
    assert.equal(readFileSync(join(packageDirectory, "README.md"), "utf8"), readme);
    assert.equal(JSON.parse(readFileSync(join(packageDirectory, "package.json"), "utf8")).private, undefined);
  }
  assert.equal(JSON.parse(readFileSync(join(main, "package.json"), "utf8")).license, "MIT");
  assert.equal(JSON.parse(readFileSync(join(native, "package.json"), "utf8")).license, "SEE LICENSE IN DISTRIBUTION.md");
}

function checkFix() {
  const path = join(directory, "fix file.res");
  writeFileSync(path, "input->consume\ndone()\n");
  assert.equal(cli(["fix file.res"]).status, 1);
  const fixed = cli(["--fix", "fix file.res"]);
  assert.equal(fixed.status, 0, fixed.stderr);
  assert.equal(readFileSync(path, "utf8"), "input->consume\n\ndone()\n");
  assert.equal(cli(["--fix", "fix file.res"]).status, 0);
}

try {
  install();
  checkContents();
  checkContracts();
  checkFix();
  process.stdout.write(`Packed npm CLI passed on ${target.id} with no OCaml tools on PATH.\n`);
} finally {
  rmSync(directory, { recursive: true, force: true });
}
