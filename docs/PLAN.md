# Project Plan

## Goal

Provide fast, useful, and maintainable static analysis for ReScript projects, with diagnostics that work in terminals, CI, editors, and eventually language-server integrations.

## Non-goals for the first release

- Reimplementing the ReScript parser or type checker.
- Formatting code.
- Automatically fixing code before diagnostics and source ranges are trustworthy.
- Supporting third-party rules before the built-in rule API is stable.

## Milestones

Current progress: OCaml 5.5.0, Dune 3.24.2, and OCamlformat 0.29.0 are installed. The official ReScript 12.3.1 parser is integrated through a pinned submodule and build adapter. The CLI parses implementations/interfaces, preserves syntax failures and UTF-8 byte ranges, and runs tested syntax-only `no-console`, `no-object-magic`, and `no-unsafe` rules through a shared traversal. The cast rule targets the actual runtime spelling, `Obj.magic`; unsafe APIs follow an explicit inventory checked against the pinned interfaces. See [DEPENDENCIES.md](DEPENDENCIES.md) for the integration boundary and [RULES.md](RULES.md) for resolution limits.

Next rule: bounded `react/rules-of-hooks` checks. Module alias/open resolution is also important for the existing rules, followed by JSON diagnostics and deterministic directory discovery. Checked exception handling requires the later semantic integration milestone.

### 0. Parser and integration spike

- Install a reproducible OCaml/Dune toolchain.
- Identify the smallest supported dependency surface from the ReScript compiler.
- Parse `.res` and `.resi` files and preserve filename, byte offsets, line/column positions, and parse errors.
- Print a sample AST and prove that one rule can inspect it.
- Record the supported ReScript compiler versions.

Exit criterion: a test fixture can be parsed and a deliberately simple diagnostic is emitted with an accurate source range.

### 1. Vertical-slice CLI

- Add a `rescript-lint` executable.
- Accept files and directories, with deterministic traversal.
- Define a diagnostic model: rule id, severity, message, file, range, and optional help/fix.
- Support human-readable output and stable JSON output.
- Return useful exit codes for clean input, lint findings, usage errors, and parse failures.

Exit criterion: the tool can run in CI against a small fixture project without invoking the ReScript compiler as a subprocess.

### 2. Rule engine and initial rules

- Define a small rule interface over syntax nodes plus shared context.
- Make rule configuration explicit and versionable.
- Add fixtures for valid, invalid, boundary, and multiline cases.
- Implement `no-console`, `no-object-magic`, and `no-unsafe` first, following [the rule contracts](RULES.md).
- Add a bounded `react/rules-of-hooks` check for obvious placement mistakes.
- Add suppression comments only after the diagnostic locations are stable.

Exit criterion: at least three useful rules, each with positive and negative fixtures, JSON output, and documented configuration.

### 3. Project awareness

- Read `rescript.json` and establish project roots and ignore behavior.
- Investigate compiler metadata for resolved callees and cross-file `@throws` annotations.
- Implement `no-unhandled-throws` as an error requiring actual exception handling; caller annotations do not satisfy it.
- Study ReScript's existing exception analyzer for implementation ideas and compatibility constraints.
- Avoid making type checking a requirement for syntax-only rules.

Exit criterion: the CLI behaves predictably in a multi-package ReScript workspace.

### 4. Distribution and integrations

- Publish versioned binaries or a package appropriate to the selected implementation language.
- Add editor/CI examples.
- Define compatibility policy for ReScript compiler versions.
- Evaluate a language-server or Tree-sitter adapter only after the CLI contract is stable.

## Suggested architecture

```text
CLI
  -> configuration and file discovery
  -> parser adapter
  -> AST traversal and optional semantic context
  -> rule runner
  -> diagnostics
  -> terminal / JSON reporters
```

Keep diagnostics and reporting independent of compiler types. Allow initial rules to use the compiler AST through a small integration layer; defer a normalized AST until concrete rules justify one. Semantic rules may need compatible build artifacts, while syntax checks should remain usable without a project build. Missing semantic inputs must be reported rather than treated as a clean lint result.

## Initial rule contracts

See [RULES.md](RULES.md) for the five requested rules, handling semantics, acceptance cases, and existing-tooling references.

Prefer rules with clear intent and low false-positive risk. A small set of trusted rules is more valuable than a large noisy catalog.

## Questions to answer during the spike

- Can the official compiler AST be consumed as a stable library without copying a large part of the compiler repository?
- Is the parser API tolerant enough for editor-style incomplete files?
- Which source-location type should be exposed publicly?
- Does the compiler preserve `@throws` annotations on implementations, interfaces, and external declarations in reusable metadata?
- What compiler-version policy is practical for users?
- Do we need a lossless concrete syntax tree for future fixes, or is the compiler AST sufficient?
