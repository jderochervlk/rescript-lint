import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { delimiter, dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import * as launcher from "../../npm/lib/launcher.mjs";
import * as platform from "../../npm/lib/platform.mjs";
import compliance from "../../scripts/npm/compliance.cjs";

const require = createRequire(import.meta.url);
const manifest = require("../../npm/package.json");
const detected = launcher.detectHost(process);
assert.equal(detected._tag, "Host");
const selected = platform.selectTarget(detected.host);
assert.equal(selected._tag, "Target");
const target = selected.target;
const artifacts = resolve("dist/npm", target.id);
const directory = realpathSync(mkdtempSync(join(tmpdir(), "rescript npm smoke ")));

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

function cli(args, input) {
  const bin = join(directory, "node_modules", ".bin", "rescript-lint");
  // cmd.exe is used only for a fixed shim command; file arguments stay with Node.
  if (process.platform === "win32") {
    const shim = spawnSync("cmd.exe", ["/d", "/s", "/c", '"node_modules\\.bin\\rescript-lint.cmd --version"'],
      { cwd: directory, env: cleanEnvironment(), encoding: "utf8", windowsVerbatimArguments: true });
    assert.equal(shim.status, 0, shim.stderr);
    assert.equal(shim.stdout.trim(), manifest.version);
    return spawnSync(process.execPath,
      [join(directory, "node_modules", manifest.name, "bin/rescript-lint.mjs"), ...args],
      { cwd: directory, env: cleanEnvironment(), encoding: "utf8", input, timeout: 30_000 });
  }
  return spawnSync(bin, args, { cwd: directory, env: cleanEnvironment(), encoding: "utf8", input, timeout: 30_000 });
}

function lspFrame(message) {
  const body = JSON.stringify(message, null, 2).replaceAll("\n", "\r\n");
  return `Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`;
}

function lspResponses(bytes) {
  if (bytes.length === 0) return [];
  const headerEnd = bytes.indexOf("\r\n\r\n");
  assert.ok(headerEnd >= 0, "LSP headers must end with CRLF CRLF.");
  const header = bytes.subarray(0, headerEnd).toString("ascii");
  const match = /^Content-Length: ([0-9]+)\r\nContent-Type: [^\r\n]+$/.exec(header);
  assert.ok(match, `Invalid LSP header: ${JSON.stringify(header)}`);
  const bodyStart = headerEnd + 4;
  const bodyEnd = bodyStart + Number(match[1]);
  assert.ok(bodyEnd <= bytes.length, "LSP body must match Content-Length.");
  const response = JSON.parse(bytes.subarray(bodyStart, bodyEnd).toString("utf8"));
  return [response, ...lspResponses(bytes.subarray(bodyEnd))];
}

function checkLsp() {
  const input = [
    { jsonrpc: "2.0", id: 1, method: "initialize", params: {
      capabilities: {}, clientInfo: { name: "npm smoke \u00e9" },
    } },
    { jsonrpc: "2.0", method: "initialized", params: {} },
    { jsonrpc: "2.0", id: 2, method: "shutdown" },
    { jsonrpc: "2.0", method: "exit" },
  ].map(lspFrame).join("");
  const result = cli(["lsp", "--stdio"], input);
  assert.equal(result.status, 0, `${result.error ?? ""}\n${result.stderr}`);
  const responses = lspResponses(Buffer.from(result.stdout, "utf8"));
  assert.equal(responses.length, 2);
  assert.equal(responses[0].id, 1);
  assert.equal(responses[0].result.capabilities.positionEncoding, "utf-16");
  assert.deepEqual(responses[0].result.serverInfo, { name: "rescript-lint", version: manifest.version });
  assert.deepEqual(responses[1], { jsonrpc: "2.0", id: 2, result: null });
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
    ["DISTRIBUTION.md", "LICENSE", "README.md", "bin", "config.schema.json", "lib", "package.json", "targets.json"]);
  assert.deepEqual(readdirSync(native).sort(), ["DISTRIBUTION.md", "LICENSE", "README.md", "bin", "package.json", "third-party"]);
  assert.equal(compliance.validateBundle(resolve("."), join(native, "bin", target.binary), join(native, "third-party")), undefined);
  assert.deepEqual(readdirSync(join(main, "bin")), ["rescript-lint.mjs"]);
  assert.deepEqual(readdirSync(join(main, "lib")).sort(), ["launcher.mjs", "platform.mjs"]);
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

function checkConfiguration() {
  const schema = JSON.parse(readFileSync(join(directory, "node_modules", manifest.name, "config.schema.json"), "utf8"));
  writeFileSync(join(directory, "configuration.json"), JSON.stringify({
    $schema: "./node_modules/@jvlk/rescript-lint/config.schema.json",
    rules: { "no-restricted-modules": true },
    restrictions: [{ kind: "type", path: "Array.t", message: "Use a list." }],
  }));
  const inspection = cli(["--config", "configuration.json", "--inspect-config", "missing.res", "--format", "json"]);
  assert.equal(inspection.status, 0, inspection.stderr);
  const effective = JSON.parse(inspection.stdout);
  assert.equal(effective.analysis, "not-run");
  assert.equal(effective.rules.length, 124);
  assert.deepEqual(effective.rules.map(rule => rule.id).sort(), Object.keys(schema.properties.rules.properties).sort());
  assert.equal(effective.rules.find(rule => rule.id === "no-restricted-modules").origin, "configuration.json");
  writeFileSync(join(directory, "policy.resi"), "let value: Array.t<int>\n");
  const linted = cli(["--config", "configuration.json", "--format", "json", "policy.resi"]);
  assert.equal(linted.status, 1, linted.stderr);
  const report = JSON.parse(linted.stdout);
  assert.equal(report.diagnostics.length, 1);
  assert.deepEqual(report.diagnostics[0].symbol, { kind: "type", path: "Array.t" });
  assert.deepEqual(report.diagnostics[0].help, { message: "Use a list.", url: null });
}

function checkProject() {
  const project = join(directory, "project files");
  const dependency = join(directory, "dependency files");
  const generated = process.platform === "win32" ? "Generated" : "generated";
  mkdirSync(join(project, "src", generated), { recursive: true });
  mkdirSync(join(dependency, "src"), { recursive: true });
  writeFileSync(join(project, "rescript.json"), JSON.stringify({ sources: [{ dir: "src", subdirs: true }] }));
  writeFileSync(join(project, "src", "Main.res"), "let value = 1\n");
  assert.equal(cli(["--project", project]).status, 0);
  writeFileSync(join(project, "src", generated, "Broken.res"), "let =\n");
  writeFileSync(join(dependency, "rescript.json"), JSON.stringify({ name: "fixture-dependency", sources: "src" }));
  writeFileSync(join(dependency, "src", "Api.res"), "let value = 1\n");
  writeFileSync(join(directory, "project.json"), JSON.stringify({
    root: "project files", exclude: ["src/generated"], throwsDependencies: ["dependency files"],
  }));
  const configured = cli(["--config", "project.json"]);
  assert.equal(configured.status, 0, `${configured.stdout}\n${configured.stderr}`);
  writeFileSync(join(project, "rescript.json"), JSON.stringify({ sources: "../dependency files/src" }));
  const escaped = cli(["--project", project]);
  assert.equal(escaped.status, 2, escaped.stderr);
  assert.match(escaped.stderr, /inside the project root/);
}

function checkOverrides() {
  const source = join(directory, "override files", "src");
  const generated = process.platform === "win32" ? "Generated" : "generated";
  mkdirSync(join(source, generated), { recursive: true });
  mkdirSync(join(source, "generated-other"), { recursive: true });
  const matched = join(source, generated, "Main.res");
  const sibling = join(source, "generated-other", "Main.res");
  writeFileSync(matched, "Console.log(1)\n");
  writeFileSync(sibling, "Console.log(1)\n");
  writeFileSync(join(directory, "overrides.json"), JSON.stringify({ overrides: [
    { paths: ["override files/src/generated"], rules: { "no-console": false } },
  ] }));
  assert.equal(cli([matched]).status, 1);
  const overridden = cli(["--config", "overrides.json", matched]);
  assert.equal(overridden.status, 0, `${overridden.stdout}\n${overridden.stderr}`);
  assert.equal(cli(["--config", "overrides.json", sibling]).status, 1);
  const inspection = cli(["--config", "overrides.json", "--inspect-config", matched, "--format", "json"]);
  assert.equal(inspection.status, 0, inspection.stderr);
  const noConsole = JSON.parse(inspection.stdout).rules.find(rule => rule.id === "no-console");
  assert.equal(noConsole.enabled, false);
  assert.equal(noConsole.origin, "overrides.json overrides[0]");
}

try {
  install();
  checkContents();
  checkContracts();
  checkLsp();
  checkFix();
  checkConfiguration();
  checkProject();
  checkOverrides();
  process.stdout.write(`Packed npm CLI passed on ${target.id} with no OCaml tools on PATH.\n`);
} finally {
  rmSync(directory, { recursive: true, force: true });
}
