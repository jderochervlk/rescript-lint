# Project Plan

## Goal

Provide fast, useful, and maintainable static analysis for ReScript projects, with diagnostics that work in terminals, CI, editors, and eventually language-server integrations.

## Non-goals for the first release

- Reimplementing the ReScript parser or type checker.
- Formatting code.
- Automatically fixing code before diagnostics and source ranges are trustworthy.
- Supporting third-party rules before the built-in rule API is stable.

## Milestones

### 0. Parser and integration spike

- Install a reproducible OCaml/Dune toolchain.
- Identify the smallest supported dependency surface from the ReScript compiler.
- Parse `.res` files and preserve filename, byte offsets, line/column positions, and parse errors.
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
- Start with high-signal rules that are syntax- or project-convention-based, such as banned APIs, suspicious attributes, and unnecessary constructs.
- Add suppression comments only after the diagnostic locations are stable.

Exit criterion: at least three useful rules, each with positive and negative fixtures, JSON output, and documented configuration.

### 3. Project awareness

- Read `rescript.json` and establish project roots and ignore behavior.
- Decide whether rules need typed information and, if so, define a separate typed-analysis boundary.
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
  -> normalized source model
  -> rule runner
  -> diagnostics
  -> terminal / JSON reporters
```

The parser adapter should be the only layer that knows about compiler-specific AST types. Rules should depend on a narrow traversal and location API where practical. This keeps compiler upgrades localized and preserves the option of a Rust implementation later.

## First rules to investigate

- Banned module, function, or operator usage.
- Attributes that are forbidden in production code.
- Project-specific React or browser API conventions.
- Unused or suspicious bindings, only if the compiler exposes enough semantic information reliably.

Prefer rules with clear intent and low false-positive risk. A small set of trusted rules is more valuable than a large noisy catalog.

## Questions to answer during the spike

- Can the official compiler AST be consumed as a stable library without copying a large part of the compiler repository?
- Is the parser API tolerant enough for editor-style incomplete files?
- Which source-location type should be exposed publicly?
- Does the compiler expose typed information in a reusable form, or should typed rules be a later integration?
- What compiler-version policy is practical for users?
- Do we need a lossless concrete syntax tree for future fixes, or is the compiler AST sufficient?

