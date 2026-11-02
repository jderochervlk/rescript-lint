# User-facing rule documentation

Created: 2026-11-02
Last updated: 2026-11-02
Status: Implemented
Issue: none

## Purpose and supported behavior

The [README](../../README.md) provides consumer installation, CLI usage,
configuration, editor setup, and the complete categorized rule list.
All 124 registered rules have an individual Markdown page at
`docs/rules/<rule-id>.md`, preserving namespace directories. Each page includes
default activation, category, autofix support, incorrect and correct ReScript
examples, configuration, and relevant limitations.

The [rule reference conventions](../rules/README.md) describe maintenance
requirements. Existing detailed rule and analysis contracts remain linked
references rather than being replaced or bulk-moved.

## Usage and design

- Start with the README, then follow a rule name to its individual page.
- Configuration examples use this linter's boolean settings, with adapters,
  limits, and project prerequisites where needed.
- Correct/incorrect examples demonstrate the named rule, not compliance with
  every optional rule. Excerpts may use application helpers from their context.
- `blank-lines` is the only rule advertising rule-specific autofixes. The
  README distinguishes these from formatting performed by `--fix`.
- Editor instructions describe the actual VSIX/development-extension routes,
  not nonexistent marketplace releases. They explain Zed's older `.cjs`
  fallback and the current package's explicit `.mjs` override.
- The VS Code integration does not automatically discover a rule configuration.
  Zed's explicit binary arguments can pass `--config`.

The structure follows eslint-plugin-unicorn's user-facing rule table and
per-rule examples/options pattern, without adopting ESLint's configuration API.
Diagnostic links remain separate from the documentation and audit changes and
belong to the subsequent PR.

## Self-contained reference update

Rule examples and essential limitations now live on the individual rule pages.
The old aggregate example document and generic example/boundary footer
redirects have been removed. Equivalent older snippets were consolidated;
distinct scenarios remain as named incorrect/correct pairs on their rule pages.
There are 130 pairs across the 124 registered rule pages.

The compiler audit reads primary and named example pairs directly from each
registered rule page. It uses the documented JSON options, validates the raw
configuration with the CLI, and enables only the target rule for example checks.
Each half is compiled in an isolated fixture project. Explicit filename
comments preserve multi-file layouts, and unused-export examples use fresh real
Reanalyze evidence.

Missing pages or pairs, invalid configuration, unsafe fixture paths, compilation
failures, and missing analysis evidence fail the audit. Empty-file, file-length,
license-header, and rethrow examples are not given an added prelude that would
change their meaning. The [audit instructions](../rules/README.md#compiler-audit)
describe the pinned dependencies and command.

This follow-up expands the original Markdown-only scope to documentation and
its development validation, without changing runtime lint behavior.

## Validation

### Initial documentation delivery

Validation performed on 2026-11-02:

- `make check`, with `DUNE_ROOT=.` to select this nested checkout and
  `OPAMSWITCH` selecting the existing OCaml 5.5 toolchain: passed build,
  formatting, OCaml lint (488 sources, zero findings), and tests.
- `python3 "$DELTA_SCRATCH_DIR/validate_rule_docs.py"`: a temporary audit
  compared all pages with the runtime `--list-rules` inventory and rule metadata,
  checked required sections and relative links/anchors, passed all 124 JSON
  configurations through `--inspect-config`, and verified 240 single-file
  incorrect/correct examples with only the target rule enabled.
- `python3 "$DELTA_SCRATCH_DIR/compile_rule_docs.py"`: compiled those 240
  examples with ReScript 12.3.1, `@rescript/react` 0.15.0, and
  `rescript-vitest` 3.0.1. Application-context excerpts used the existing
  `scripts/examples/rule-example-prelude.res` fixture. Compiler warnings were
  retained; there were no compilation errors.
- `python3 "$DELTA_SCRATCH_DIR/check_project_rule_docs.py"`: compiled and
  checked eight multi-file cases for source-root restrictions, restricted
  modules, unused exports, and required interfaces. Real Reanalyze reports
  were generated for the unused-export examples. All eight passed.
- A separate Python check verified all 124 README rows, matching defaults and
  fixability, relative links and anchors across all 129 affected Markdown
  files, and verbatim preservation of the original committed plan.
  The documented `blank-lines` example was fixed through the CLI, then fixed
  again to verify clean output and idempotence.
- `git diff --check`: passed.

The audit scripts and generated projects were temporary validation artifacts,
not additions to the package or production code. Editor installation and
standard diagnostic-link support were checked against the extension repositories
and client implementations, not by running live editors. Packaging and coverage
commands were not needed for that initial Markdown-only change.

### Self-contained examples and audit migration

Validation performed on 2026-11-02:

- `node --test test/examples/audit-rule-examples.test.mjs`: all eight tests
  passed, covering primary/named pairs, namespaces, shared setup, configuration,
  malformed sections, explicit files, traversal rejection, and result accounting.
- `node scripts/examples/audit-rule-examples.mjs _build/default/bin/main.exe "$DELTA_SCRATCH_DIR/rule-doc-audit"`:
  all 260 cases compiled and passed their target-rule checks, with zero skips.
  The fixture used ReScript 12.3.1, `@rescript/react` 0.15.0, and
  `rescript-vitest` 3.0.1. This included fresh Reanalyze checks for the
  multi-file unused-export examples.
- `DUNE_ROOT=. make check`: build, formatting, OCaml lint, and tests passed,
  including the eight audit tests through Dune.
- Inventory checks confirmed that all 124 registered rule pages retain
  metadata, primary incorrect/correct examples, and configuration; 130 matched
  pairs cover the primary examples and six additional scenarios.
- Relative links and anchors across the relevant documentation resolved;
  `git diff --check` passed. No active documentation or tool reads the removed
  aggregate examples file.

Runtime rule detection and package code were unchanged; coverage and packaging
checks were not rerun for this documentation/development-audit follow-up.

## Historical planning record

### Original committed plan

Plan created: 2026-11-02
Plan last updated: 2026-11-02

The original plan is preserved verbatim below as historical intent, not an
active checklist.

```markdown
# User-facing rule documentation

Created: 2026-11-02
Last updated: 2026-11-02
Status: Planned
Issue: none
Feature documentation: pending

## Problem and intended outcome

Users need a discoverable reference for every registered rule, including
incorrect and correct ReScript examples, configuration, prerequisites, and
autofix support. The README should explain installation and everyday use,
including the VS Code and Zed integrations, and link to the complete rule list.

## Scope and non-goals

This first PR changes Markdown documentation only. It covers all 124 currently
registered rules and preserves the existing detailed analysis contracts.
Diagnostic links, CLI output, JSON output, and LSP protocol changes belong in
a separate second PR. Neither PR will be merged without separate authorization.

## Approach and decisions

- Follow eslint-plugin-unicorn's user-focused README and per-rule reference
  structure, while retaining this project's boolean rule configuration.
- Use `docs/rules/<rule-id>.md`, preserving namespace directories such as
  `react/`, `jsx-a11y/`, and `test/`. This gives the later diagnostic-link PR
  one deterministic GitHub URL for each registered ID.
- Derive the inventory, categories, and default activation from the current
  rule catalog and each rule's metadata. Check examples and options against
  implementation and tests, not only older aggregate documentation.
- State fixability explicitly on every page. Distinguish rule-specific fixes
  from formatting performed by the `--fix` command.
- Document editor installation methods actually supported by the extension
  repositories; do not imply unpublished extensions are in a marketplace.
- Keep historical work logs and deep analysis references out of the README's
  primary onboarding path, linking to them where appropriate.

## Implementation steps

- [ ] Write a page for every registered rule with a common readable structure.
- [ ] Include incorrect/correct examples and usable JSON/CLI configuration,
  including required adapters, project context, and nondefault example limits.
- [ ] Rewrite README onboarding and add a linked rule table with defaults,
  categories, descriptions, and fixability.
- [ ] Verify VS Code and Zed installation instructions against their manifests
  and repositories.
- [ ] Check inventory coverage, Markdown links, JSON examples, and example
  behavior, then run `make check`.
- [ ] Promote this plan to living feature documentation with its original
  planning record and actual validation results.
- [ ] Open the documentation PR before preparing the diagnostic-link PR.

## Validation

Planned checks: compare pages and README rows with all registered IDs; validate
relative Markdown links and JSON configuration examples; run documented examples
against the current CLI where their required context is available; run
`make check`; inspect the final documentation-only diff.

Actual checks and any environment blockers will be recorded as work proceeds.

## Open questions and remaining work

The diagnostic-link PR will target these GitHub pages only after the
documentation PR is open. The extension repositories are separate projects and
are not attached for editing; core LSP diagnostic metadata is the intended
integration point for rule links.
```

### Dated decisions and implementation results

- 2026-11-02: Started from current GitHub `main` because the attached
  `docs/consumer-readme` branch had already been merged. The current registry
  contains 124 rules, not the older checkout's 105.
- 2026-11-02: Retained all existing aggregate contracts and added individual
  pages. Removed unsupported configuration claims found in review and supplied
  explicit type/project context where required for examples to report findings.
- 2026-11-02: Confirmed neither editor integration is published. Documented
  supported development installation and current launcher compatibility instead
  of presenting marketplace or automatic-upgrade instructions that do not work.
- 2026-11-02: All 248 incorrect/correct examples passed targeted lint checks and
  compiler validation in their stated single-file or multi-file contexts.
  The documentation PR is the first delivery; diagnostic-link implementation
  remains separate.

### Self-contained rule documentation plan

Plan created: 2026-11-02
Plan last updated: 2026-11-02

The original committed follow-up plan is preserved verbatim below.

```markdown
# Self-contained rule documentation

Created: 2026-11-02
Last updated: 2026-11-02
Status: Planned
Issue: none
Feature documentation: [rule documentation](../features/rule-documentation.md)

## Problem and intended outcome

Individual rule pages still send readers to aggregate examples and boundaries.
Users should find the examples, relevant configuration, setup, and limitations
for a rule on that rule's page. Remove the aggregate examples document without
losing useful examples or leaving its audit command broken.

## Scope and non-goals

Update documentation PR #54, leaving diagnostic-link behavior in dependent
PR #55 unchanged. Remove generic example/boundary footer redirects, retain
distinct useful examples in the appropriate rule pages, remove stale index
references, and teach the existing development audit to read those pages.
No rule detection, configuration semantics, production dependencies, or editor
extension changes are included. Do not merge either PR.

## Approach and decisions

- Individual `docs/rules/<id>.md` pages are the single source for examples.
  Keep the existing improved primary incorrect/correct pairs; consolidate
  equivalent older examples rather than duplicating them verbatim.
- Preserve distinct scenarios from the old aggregate under the corresponding
  rule, with their required setup and boundaries inline.
- Keep `### Incorrect` and `### Correct` as the primary example pair and JSON
  configuration on each page. Additional scenarios may follow as clearly
  labeled examples without replacing the primary pair.
- Move the example audit to registered rule pages and their documented
  configuration. Keep compiler validation, isolated target-rule checks,
  project fixtures, and real Reanalyze evidence; never silently skip a rule.
- Necessary audit-input changes belong with the documentation change. This
  expands the original Markdown-only scope to documentation plus development
  validation, not runtime behavior.
- Synchronize the dependent branch with an ordinary non-rewriting merge after
  updating PR #54, so PR #55 does not restore removed documentation.

## Implementation steps

- [ ] Compare the aggregate examples with all 124 individual rule pages.
- [ ] Consolidate useful examples and inline essential boundaries, removing
  generic cross-file example/boundary footers.
- [ ] Remove the aggregate examples document and repair indexes/references.
- [ ] Migrate and regression-test the audit's per-rule-page input.
- [ ] Run the audit with the pinned compiler/adapters, validate documentation
  links and inventory, and run `make check`.
- [ ] Consolidate this plan into the existing feature record, preserving the
  original plan and dated scope decision.
- [ ] Update PR #54 and synchronize dependent PR #55 without landing either.

## Validation

Planned commands: focused Node audit-input tests, the existing
`node scripts/examples/audit-rule-examples.mjs BINARY FIXTURE_PROJECT` command
against the pinned compiler/adapters, `make check`, and `git diff --check`.
Check all registered pages for incorrect/correct examples and configuration,
ensure active links resolve, and ensure no tool still reads the removed file.
Record exact actual outcomes and any blockers separately.

## Open questions and remaining work

No unresolved product decisions. Optional deep technical references can remain,
but a reader must not need them to find a rule's examples or understand its
documented supported subset.
```

### Follow-up decisions and results

- 2026-11-02: Made individual rule pages the sole examples source after user
  feedback. Consolidated equivalent older snippets and retained distinct
  callback implementation, specific exception recovery, awaited promise,
  static JSX key, focused-suite, and skipped-suite scenarios inline.
- 2026-11-02: Replaced generic boundary redirects with concrete supported
  subsets. Kept optional deep technical references where appropriate.
- 2026-11-02: Migrated the audit rather than leaving it dependent on a removed
  document. The final audit passed all 260 cases; no runtime rules were changed.
