import { globSync, readFileSync, mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

export const sourceRoots = ["lib", "bin", "test", "scripts"];
export const generatedSources = ["lib/unsafe_apis/banned_runtime_data.ml"];

export function sources() {
  return globSync(sourceRoots.map((root) => `${root}/**/*.{ml,mli}`))
    .filter((path) => !generatedSources.includes(path)).sort();
}

// Use the compiler's source names and annotated artifacts, including (test)
// executables. Never infer module names from include_subdirs or Dune wrapping.
export function workspace(files, artifacts) {
  const entries = files.map((source) => {
    const matches = artifacts.filter((entry) => entry.source === source);
    if (matches.length !== 1 || !matches[0].fresh) {
      throw new Error(`Expected one current typed artifact for ${source}, found ${matches.length}`);
    }
    const { artifact } = matches[0];
    const intf = source.endsWith(".mli");
    const quote = (text) => JSON.stringify(text);
    return `(executables ((names ()) (modules (((name Lint_source)
      (${intf ? "intf" : "impl"} (${quote(source)}))
      (${intf ? "impl" : "intf"} ())
      (${intf ? "cmti" : "cmt"} (${quote(artifact)}))
      (${intf ? "cmt" : "cmti"} ())))) (requires ()) (include_dirs ())))`;
  });
  if (entries.length === 0) throw new Error("No first-party OCaml sources found");
  return `(${entries.join("\n")})\n`;
}

export function diagnostics(output, files) {
  const selected = new Set(files);
  return output.split("\n").filter((line) => line.trim()).map((line) => {
    const entry = JSON.parse(line);
    const { path, range } = entry.location ?? {};
    if (!selected.has(path) || typeof entry.message !== "string"
      || typeof entry.code?.value !== "string"
      || !Number.isInteger(range?.start?.line) || range.start.line < 1) {
      throw new Error("Invalid or out-of-scope Zanuda diagnostic");
    }
    return entry;
  });
}

// Exceptions apply only to the reviewed rule, line, and exact source text.
// Stale exceptions fail rather than quietly covering replacement code.
export function applyExceptions(findings, exceptions, readSource = (path) => readFileSync(path, "utf8"), files = sources()) {
  const covered = new Set();
  const selected = new Set(files);
  for (const exception of exceptions) {
    if (exception.rule !== "mutability_check" || !exception.reason?.trim()
      || !selected.has(exception.path) || !exception.sites?.length) {
      throw new Error("Invalid OCaml lint exception");
    }
    const lines = readSource(exception.path).split("\n");
    for (const [line, text] of exception.sites) {
      if (lines[line - 1]?.trim() !== text) throw new Error(`Stale exception at ${exception.path}:${line}`);
      const matches = findings.filter((entry) => entry.location.path === exception.path
        && entry.location.range.start.line === line && entry.code.value === exception.rule);
      if (matches.length === 0) throw new Error(`Unused exception at ${exception.path}:${line}`);
      for (const entry of matches) {
        if (covered.has(entry)) throw new Error("Duplicate OCaml lint exception");
        covered.add(entry);
      }
    }
  }
  return findings.filter((entry) => !covered.has(entry));
}

export function validatePolicy(text, rules) {
  const ids = new Set(rules.map((rule) => rule.id));
  const disabled = text.split("\n").filter((line) => line.trim());
  for (const line of disabled) {
    if (!line.startsWith("-no-") || !ids.has(line.slice(4))) {
      throw new Error(`Invalid Zanuda policy option: ${line}`);
    }
  }
  if (new Set(disabled).size !== disabled.length) throw new Error("Duplicate Zanuda policy option");
}

export function toolOutput(program, result) {
  if (result.error) throw result.error;
  if (result.status !== 0 || result.stderr.trim()) {
    throw new Error(`${program} failed (${result.status ?? result.signal}): ${result.stderr || result.stdout}`);
  }
  return result.stdout;
}

function command(program, args, options = {}) {
  return toolOutput(program, spawnSync(program, args, { encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024, ...options }));
}

export function lint() {
  const files = sources();
  const artifacts = JSON.parse(command("dune", ["exec", "scripts/lint/artifact_manifest.exe", "--",
    ...sourceRoots.map((root) => `_build/default/${root}`)]));
  const temporary = mkdtempSync("_build/ocaml-lint-");
  try {
    if (command("opam", ["var", "zanuda:version"]).trim() !== "2.1.0") {
      throw new Error("OCaml lint requires Zanuda 2.1.0; install development dependencies");
    }
    command("zanuda", ["-dump-lints", join(temporary, "rules.json")]);
    validatePolicy(readFileSync(".zanuda", "utf8"), JSON.parse(readFileSync(join(temporary, "rules.json"), "utf8")));
    const description = workspace(files, artifacts);
    writeFileSync(join(temporary, "workspace.sexp"), description);
    // Zanuda 2.1.0 internally invokes exactly this command. Restrict the shim
    // to that call; other invocations must fail, never silently skip analysis.
    writeFileSync(join(temporary, "dune"), `#!/bin/sh
if [ "$#" -eq 3 ] && [ "$1" = describe ] && [ "$2" = workspace ] && [ "$3" = . ]; then
  cat "$OCAML_LINT_WORKSPACE"
else
  echo "Unexpected Zanuda Dune invocation" >&2
  exit 1
fi
`, { mode: 0o755 });
    const absolute = join(process.cwd(), temporary);
    command("zanuda", ["-no-check-filesystem", "-dir", ".", "-ordjsonl", join(absolute, "diagnostics.jsonl")], {
      env: { ...process.env, PATH: `${absolute}:${process.env.PATH}`,
        OCAML_LINT_WORKSPACE: join(absolute, "workspace.sexp") },
    });
    const findings = diagnostics(readFileSync(join(temporary, "diagnostics.jsonl"), "utf8"), files);
    const remaining = applyExceptions(findings, JSON.parse(readFileSync(".ocaml-lint-exceptions.json", "utf8")));
    for (const entry of remaining) {
      process.stdout.write(`${entry.location.path}:${entry.location.range.start.line}: [${entry.code.value}] ${entry.message.trim()}\n`);
    }
    process.stdout.write(`OCaml lint: ${files.length} sources, ${remaining.length} findings (${findings.length - remaining.length} justified exceptions)\n`);
    return remaining.length === 0 ? 0 : 1;
  } finally {
    rmSync(temporary, { recursive: true, force: true });
  }
}
