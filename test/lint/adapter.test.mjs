import { test } from "node:test";
import assert from "node:assert/strict";
import { workspace, diagnostics, toolOutput, applyExceptions, validatePolicy, sources } from "../../scripts/lint/lint.mjs";

const file = "test/example.ml";
const artifact = { source: file, artifact: "_build/default/test/.example.eobjs/byte/dune__exe__Example.cmt", fresh: true };
const finding = (rule = "mutability_check", line = 1) => ({
  message: "A finding", code: { value: rule }, location: { path: file, range: { start: { line } } },
});

test("workspace covers tests and interfaces and filters generated/vendor artifacts", () => {
  const intf = { source: "lib/example.mli", artifact: "_build/default/lib/example.cmti", fresh: true };
  const result = workspace([file, intf.source], [artifact, intf,
    { source: "vendor/a.ml", artifact: "vendor/a.cmt", fresh: true },
    { source: "lib/example.ml-gen", artifact: "generated.cmt", fresh: true }]);
  assert.match(result, /dune__exe__Example.cmt/);
  assert.match(result, /\(cmti \("_build\/default\/lib\/example.cmti"\)\)/);
  assert.doesNotMatch(result, /vendor|generated/);
  assert(!sources().some((path) => /^(vendor|_opam|_build)\//.test(path)));
  assert(!sources().includes("lib/unsafe_apis/banned_runtime_data.ml"));
});

test("discovery fails closed on missing, stale, duplicate, or empty inputs", () => {
  for (const artifacts of [[], [{ ...artifact, fresh: false }], [artifact, artifact]]) {
    assert.throws(() => workspace([file], artifacts), /current typed artifact/);
  }
  assert.throws(() => workspace([], []), /No first-party/);
});

test("structured diagnostics distinguish clean output from violations", () => {
  assert.deepEqual(diagnostics("", [file]), []);
  assert.deepEqual(diagnostics(`${JSON.stringify(finding())}\n`, [file]), [finding()]);
  for (const output of ["not JSON", "{}", JSON.stringify(finding("if_bool", 0)),
    JSON.stringify({ ...finding(), code: {} })]) {
    assert.throws(() => diagnostics(output, [file]));
  }
  assert.throws(() => diagnostics(JSON.stringify(finding()), ["lib/other.ml"]), /out-of-scope/);
});

test("tool failures, signals, stderr, and spawn failures cannot become clean output", () => {
  const clean = { status: 0, stdout: "", stderr: "" };
  assert.equal(toolOutput("zanuda", clean), "");
  for (const patch of [{ status: 1 }, { status: null, signal: "SIGABRT" },
    { stderr: "Skipped analysis" }, { error: new Error("spawn failure") }]) {
    assert.throws(() => toolOutput("zanuda", { ...clean, ...patch }));
  }
});

test("exceptions cover only reviewed mutation sites and retain new violations", () => {
  const exception = { path: file, rule: "mutability_check", reason: "AST callback returns unit", sites: [[1, "incr calls;"]] };
  const first = finding();
  const next = finding("mutability_check", 2);
  const other = finding("wrong_ignoring");
  const apply = (findings, exceptions) => applyExceptions(findings, exceptions, () => "incr calls;\nnew_mutation", [file]);
  assert.deepEqual(apply([first, next, other], [exception]), [next, other]);
  assert.deepEqual(apply([first], []), [first]);
  for (const patch of [{ reason: "" }, { sites: [] }, { rule: "wrong_ignoring" },
    { path: "vendor/a.ml" }, { sites: [[1, "changed code"]] }]) {
    assert.throws(() => apply([first], [{ ...exception, ...patch }]));
  }
  assert.throws(() => apply([], [exception]), /Unused/);
  assert.throws(() => apply([first], [exception, exception]), /Duplicate/);
});

test("policy rejects misspelled options and unsupported suppression commands", () => {
  const rules = [{ id: "if_bool" }];
  validatePolicy("-no-if_bool\n", rules);
  for (const text of ["-no-typo", "ignore lib/", "-no-if_bool\n-no-if_bool"]) {
    assert.throws(() => validatePolicy(text, rules));
  }
});
