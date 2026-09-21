# Rule expansion work log

Started 2026-09-20. User request: add as many reliable rules as practical within
the existing structure, work in parallel, and collect shared problems before
addressing them together.

## Starting state

- Inspected the rule candidate plan, existing traversals, parser, CLI, test
  registration, and verification scripts.
- Preserved existing uncommitted changes in README.md, docs/PLAN.md,
  docs/RULES.md, lib/linter.ml, test/dune, the control-flow rule implementation
  and tests, and the candidate/example documents.
- The existing ten-rule baseline includes four uncommitted control-flow rules.
- Implementation is OCaml with the pinned ReScript parser. No new production
  dependencies are planned.
- Applied functional-code-style and writing-functions skills.

## Parallel assignments

- Exception agent: no-debugger, no-useless-catch, no-catch-all-exception.
  Detailed log: [RULE_WORK_EXCEPTIONS.md](RULE_WORK_EXCEPTIONS.md).
- Expression agent: simplify-boolean-expression, no-useless-concat,
  approx-constant. Detailed log: [RULE_WORK_EXPRESSIONS.md](RULE_WORK_EXPRESSIONS.md).
- Policy agent: no-empty-function, no-empty-file, no-warning-comments,
  max-nesting, max-params, max-lines-per-function.
  Detailed log: [RULE_WORK_POLICIES.md](RULE_WORK_POLICIES.md).
- Main agent: baseline verification, integration, activation controls,
  documentation, shared issue review, and final verification.
- Dune builds/tests run only through the main agent to avoid competing builds.

## Deferred issues and infrastructure

- Most syntax candidates are deliberately disabled by default in the candidate
  plan. The existing engine has no activation controls. Implement rule bodies
  first, then add a small explicit enable/disable boundary so these rules are
  usable without enabling subjective policies for every user.
- Typed, project, JSX, React, and test-adapter candidates need semantic or
  project infrastructure. Do not replace those prerequisites with guesses at
  names. Keep them tracked in RULE_CANDIDATES.md.
- New rules initially provide diagnostics only. Safe rewriting, suppression
  auditing, and full project configuration remain separate infrastructure work.

## Verification history

- Baseline `make check` passed before edits.

## Integration work

- Added a central 22-rule activation registry: twelve defaults (the previous
  ten plus no-debugger/no-useless-catch) and ten opt-in policies.
- Added repeatable --enable-rule/--disable-rule flags, exact rule-ID
  validation, last-setting-wins behavior, and --list-rules.
- Threaded rule selection through CLI lint/fix/watch and LSP entry points.
  Existing default library entry points remain available.
- Disabled throws analysis is skipped explicitly; parse failures always remain
  errors. New syntax rules do not yet add fixes.

## First integrated pass and grouped follow-up

- All twelve new rules compile. Expression tests and activation tests passed
  their first integrated run.
- Exception tests exposed one unsupported local-open fixture spelling; replaced
  it with the parser-supported block-local open form.
- Policy tests exposed that `{}` is an empty record expression, documentation
  comments live in AST attributes, and single-line comment locations exclude
  their delimiters. These were recorded together before the follow-up pass.
- Reviewed the existing control-flow rules for interactions. Found false-positive
  risks from comparing switch guards across different patterns, comparing bodies
  with different pattern scopes, and remembering duplicate conditions across
  effectful tests. The expression agent is correcting these as one precision pass.
- That review also identified literal-folding risks for escaped strings, Unicode
  ordering, and integers beyond ReScript's int domain. Conservative exclusions
  and regression tests are part of the same pass.
- Added CLI regression fixtures for default and opt-in rules, invalid settings,
  last-setting-wins behavior, and preserving files when spacing is disabled.
- First integrated coverage run passed: 98.25% (2251/2291), every file at least
  90%. New expression rules and activation registry reached 100%; exception
  rules reached 98.71%, policy rules 98.37%. Report:
  `_coverage/run.yxk8nD/html/index.html`.
- Final precision review caught the parser's direct standalone-attribute
  callback, which bypasses an attributes-list override. Added explicit
  payload exclusion and regression cases to the new expression/exception
  rules and the existing control-flow pass.
- Added a user-facing reference in SYNTAX_RULES.md and updated README,
  RULES, PLAN, and RULE_CANDIDATES without replacing the existing research.

## Completed result

- Added twelve rules, covering every remaining candidate in the first syntax
  wave: two enabled by default and ten opt-in. Total registered rules: 22.
- Integrated enable/disable settings into lint, fix, watch, and LSP. Verified
  unsaved LSP buffers and both watch modes with a Bash-only CLI harness.
- Resolved the initial parser/test mismatches as a grouped follow-up. No newly
  implemented rule remains blocked or has a known failing regression test.
- Preserved original dirty work and kept the vendor checkout and dependency
  manifests unchanged. No commit, push, package publication, or dependency
  installation was performed.

## Final verification

- `make check`: build, formatting, unit tests, and Cram CLI tests passed.
- `make coverage`: 98.30% overall (2261/2300 execution points), every measured
  file at least 90%. New expression rules and rule configuration: 100%;
  exception rules: 98.72%; policy rules: 98.37%; control-flow pass: 97.61%.
- Final report: `_coverage/run.6eNcBY/html/index.html`.
- `opam exec -- dune build --profile release @install`: passed.
- `git diff --check`: passed.
- Existing Bisect tooling measures execution points, not separate statement,
  branch, function, and line coverage. No threshold or test was weakened.
- Native source changes invalidate any previously prepared npm compliance
  bundle; distribution preparation was not part of this rule expansion.

## Remaining work to address together

1. Inline suppression parsing/auditing and project/file-level configuration.
2. Numeric CLI policy options, custom warning terms, and generated-file filters.
   Numeric limits are already configurable through `Policy_rules.check`.
3. Semantic symbol/type metadata and runtime adapters before typed, JSX, React,
   test-framework, or project-wide candidate rules.
4. Wider exception alias/rethrow analysis and decoded literal comparison.
5. Safe fixes for new rules, with comment/evaluation preservation. All twelve
   additions intentionally remain diagnostic-only.

Each rule's bounded behavior is documented in SYNTAX_RULES.md; agent logs retain
the implementation details and the problems encountered before correction.
