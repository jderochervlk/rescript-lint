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

Bounded `react/rules-of-hooks` checks are now implemented in a separate contextual traversal, with placement, callback, async/default-argument, exception-region, and special-`use` tests. The implemented rules share diagnostic ordering, not one universal rule abstraction.

The first candidate control-flow wave is implemented through one conservative
syntax traversal: `no-constant-condition`,
`no-constant-binary-expression`, `no-duplicate-condition`, and
`no-identical-branches`. It performs no type or purity inference and offers no
fixes yet.

The throws rule resolves local and configured-project declaration contracts,
including `.resi` precedence, aliases and exported exception identity pairing.
Handler coverage is enforced and unsupported active analysis fails explicitly.
An explicit ReScript 12.3.1 runtime adapter supplies nine verified JSON contracts.
Explicit dependency-package contracts now support bounded namespaced public
declarations; arbitrary effects are not inferred. See [THROWS.md](THROWS.md).
The CLI watches rediscovered project inputs and reruns lint/fix.

The catalog expansion now provides 105 rule implementations, explicit adapter
configuration, deterministic project discovery, `.resi`-first public metadata,
bounded source type/identity inference, Reanalyze report freshness checks, and
audited suppression directives. See [EXTENDED_RULES.md](EXTENDED_RULES.md) and
[the overnight work log](RULE_OVERNIGHT_LOG.md). These shared project facilities
now support project-local throws declarations. Banned-API checks also use lexical
module aliases, opens/includes and configured project shadows with pinned public
runtime export shapes. Unknown exports remain outside the guarantee.

Versioned JSON diagnostics, an immutable content-checked project parse cache,
discovery-aware watch mode, configurable warning-comment terms/contexts,
per-file rule overrides, decoded string-literal comparisons, and the first
diagnostic LSP server are implemented. See [the continuation log](WORK_CONTINUATION.md),
[override work log](WORK_FILE_OVERRIDES.md),
[literal-semantics work log](WORK_LITERAL_SEMANTICS.md), and [LSP.md](LSP.md)
for their contracts and validation. Source inference is not a replacement for
the compiler's type checker; preserve explicit unknown-analysis boundaries.

The immediate release gate is live Zed validation and prerelease distribution of
the already-built LSP. The next implementation milestone, once that validation
is complete, is configuration observability: inspect the effective per-file
configuration and ship a schema for the existing strict configuration format.
Then extend `no-restricted-modules` deliberately to type uses and richer policy
guidance before considering declaration-origin restrictions or style rewrites.
See [the PR #8351 review](PR_8351_REVIEW.md) for rationale and acceptance
criteria. Publication continues to use the documented release gates.

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
- Watch explicit inputs for changes; extend watch mode to discovered directory contents when directory traversal lands.
- Define a diagnostic model: rule id, message, file, range, and optional help/fix. Rule configuration is binary: enabled findings are errors, disabled rules emit nothing, and there is no warning severity.
- Support human-readable output and stable JSON output.
- Return useful exit codes for clean input, lint findings, usage errors, and parse failures.

Exit criterion: the tool can run in CI against a small fixture project without invoking the ReScript compiler as a subprocess.

### 2. Rule engine and initial rules

- Define a small rule interface over syntax nodes plus shared context.
- Make rule configuration explicit and versionable.
- Add fixtures for valid, invalid, boundary, and multiline cases.
- Implement `no-console`, `no-object-magic`, and `no-unsafe` first, following [the rule contracts](RULES.md).
- Add a bounded `react/rules-of-hooks` check for obvious placement mistakes.
- Add auditable inline suppression comments after diagnostic locations are stable. Support line, next-line, and explicit region scopes; require exact rule IDs; report invalid, unmatched, unknown, and unused directives as errors; and do not allow comments to suppress parse, I/O, fix, or semantic-analysis failures. Follow the detailed contract in [RULE_CANDIDATES.md](RULE_CANDIDATES.md).

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
- Expose a language server over the shared lint engine, driven by LSP document notifications rather than CLI watch mode. Follow the detailed [language server plan](LSP.md).
- Extend the existing ReScript Zed extension first, then add a VS Code client for the same language server.
- Define compatibility policy for ReScript compiler versions.
- Evaluate a language-server or Tree-sitter adapter only after the CLI contract is stable.

### 5. Configuration observability and restriction precision

- Add an effective-configuration inspector that uses the same config, CLI, and
  per-file override precedence as lint, fix, watch, and LSP.
- Ship a JSON schema for the current configuration format; accept a string
  `$schema` metadata property while retaining strict runtime decoding.
- Add typed `help` and resolved-symbol metadata to policy findings consistently
  across terminal, JSON, and LSP reporting.
- Extend restriction policies only with explicit value/module/type matching and
  documented overlap precedence. Keep declaration-origin restrictions behind a
  proven provenance adapter.

Exit criterion: an inspected file reports the exact effective rule state and
configuration origin used by lint; schema and runtime decoder agreement are
tested; policy findings carry actionable context without weakening unknown-
analysis failures.

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

The syntax expansion adds twelve rules to the existing ten, with repeatable
enable/disable CLI controls shared by lint, fix, watch, and LSP modes. Two new
rules are default errors; ten policy rules remain opt-in. See
[SYNTAX_RULES.md](SYNTAX_RULES.md) for their bounded contracts and
[RULE_WORK_LOG.md](RULE_WORK_LOG.md) for implementation and verification.
Typed, runtime-adapter, and project candidates retain their documented
prerequisites. Inline suppression auditing and project configuration are implemented.

Prefer rules with clear intent and low false-positive risk. A small set of trusted rules is more valuable than a large noisy catalog.

## Questions to answer during the spike

- Can the official compiler AST be consumed as a stable library without copying a large part of the compiler repository?
- Is the parser API tolerant enough for editor-style incomplete files?
- Which source-location type should be exposed publicly?
- Does the compiler preserve `@throws` annotations on implementations, interfaces, and external declarations in reusable metadata?
- What compiler-version policy is practical for users?
- Do we need a lossless concrete syntax tree for future fixes, or is the compiler AST sufficient?
