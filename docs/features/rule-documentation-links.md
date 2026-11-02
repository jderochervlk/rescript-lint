# Rule links in diagnostics

Created: 2026-11-02
Last updated: 2026-11-02
Status: Implemented
Issue: none
Depends on: [documentation PR #54](https://github.com/jderochervlk/rescript-lint/pull/54)

## Purpose and supported behavior

Every registered rule has one catalog-backed GitHub documentation URL:
`https://github.com/jderochervlk/rescript-lint/blob/main/docs/rules/<id>.md`.
Namespaces remain directories, for example `react/rules-of-hooks.md`.
The linked pages describe examples, options, prerequisites, and fixability.

The output formats expose the same target:

- Human CLI findings append `Docs: URL` on an indented continuation line.
  Known-rule diagnostics inside analysis errors receive the same continuation
  on stderr. Diagnostic order, the first line, and exit codes are unchanged.
- JSON diagnostic objects include additive version-1 `documentationUrl`
  string/null metadata, including nested error diagnostics.
- LSP diagnostics retain the rule ID in `code` and include standard
  `codeDescription.href`. VS Code and Zed can render this as a clickable
  diagnostic code without extension-specific changes.

Unregistered codes, including `syntax`, `suppression`, and infrastructure
analysis errors, do not fabricate rule links. JSON uses null; LSP omits
`codeDescription`; human output remains unchanged for these diagnostics.

## Usage

Ordinary lint, fix, and watch reporting include links automatically:

```text
src/Main.res:1:1: error [no-console] Do not use Console.log.
  Docs: https://github.com/jderochervlk/rescript-lint/blob/main/docs/rules/no-console.md
```

No configuration or network request is required to produce the URL.
Use the [JSON contract](../diagnostics/JSON_DIAGNOSTICS.md) instead of scraping
human continuation lines. See the [LSP contract](../editor/LSP.md#rule-documentation-links)
for editor metadata.

## Design and boundaries

`Rule_documentation.url` resolves only IDs in `Rule_catalog.rules`. Reporters
and the LSP adapter share that pure resolver; there is no second rule inventory.
Low-level diagnostic construction/rendering remains independent of the catalog,
avoiding a dependency cycle through registered rule implementations.

Rule links do not replace optional custom restriction guidance or `help.url`.
LSP messages and `data`, JSON messages, symbol metadata, ranges, fixes, rule
activation, and detection remain unchanged. A registered-rule analysis-boundary
diagnostic can link to the rule even though its outcome is analysis failure
rather than an ordinary finding.

The URLs use `main` documentation, not version-pinned release documentation.
The diagnostic-link PR depends on the documentation-only PR #54, so its targets
exist on `main` before the links are landed. Neither PR is merged by this work.

## Validation

Checks performed on 2026-11-02:

- Focused diagnostic/reporting/LSP executable builds succeeded.
- `make check`, with `DUNE_ROOT=.` and the existing OCaml 5.5 Opam toolchain:
  passed build, formatting, OCaml lint (491 sources, zero findings), and tests.
  The suite checks every registered URL against an existing Markdown page,
  namespaced IDs, unknown/traversal IDs, nested analysis diagnostics, preserved
  custom guidance, exact CLI output, and real stdio serialization.
- `make coverage` with the same environment: passed the per-file 90% gate;
  project coverage was 96.61%. The resolver, human reporter, JSON reporter,
  and LSP diagnostic adapter each had 100% execution-point coverage.
- `npm run prepare:licenses` with the configured toolchain: prepared the real
  local source/license bundle.
- `OPAMSWITCH="$PWD" npm test`: all 65 tests passed, with 100% line, branch,
  and function coverage in the npm suite.
- `python3 "$DELTA_SCRATCH_DIR/smoke_diagnostic_links.py"`: an ephemeral check
  ran the actual CLI in human/JSON modes and a framed LSP initialize/open/change/
  shutdown/exit transcript. Known-rule findings carried the link, an unsaved
  syntax error did not fabricate one, and exit codes remained correct.
- `git diff --check`: passed. Independent review found no actionable issues.

Initial npm runs exposed missing local prerequisites, not source failures:
the fresh worktree had no prepared compliance bundle or local Opam switch.
License preparation and an ignored `_opam` link to the already-installed
toolchain resolved those prerequisites; the unmodified suite then passed.
No checks, types, or coverage thresholds were weakened.

No live graphical VS Code or Zed session was tested. Source rebuild and
packaged-install smoke commands were not run; no package was published.

## Historical planning record

### Original committed plan

Plan created: 2026-11-02
Plan last updated: 2026-11-02

The original committed plan is preserved verbatim below as historical intent,
not an active checklist.

```markdown
# Rule links in diagnostics

Created: 2026-11-02
Last updated: 2026-11-02
Status: Planned
Issue: none
Feature documentation: pending
Depends on: [documentation PR #54](https://github.com/jderochervlk/rescript-lint/pull/54)

## Problem and intended outcome

CLI findings and IDE diagnostics identify rules but do not provide a direct
route to their examples and configuration. Every registered rule should link
to the GitHub page introduced by the documentation PR.

## Scope and non-goals

Add documentation references to human CLI, structured JSON, and standard LSP
diagnostics. Preserve existing messages, custom restriction guidance and URLs,
ranges, fixes, ordering, and exit codes. Do not change rule detection,
configuration, editor-extension implementations, or package dependencies.
Open this as a separate dependent PR; do not merge either PR.

## Approach and decisions

- Resolve URLs from the existing rule catalog, not from a second rule list or
  arbitrary diagnostic strings. Use
  `https://github.com/jderochervlk/rescript-lint/blob/main/docs/rules/<id>.md`,
  preserving namespace directories.
- Return no documentation URL for unregistered codes such as syntax,
  suppression, and infrastructure analysis errors.
- Keep URL resolution at the reporting/LSP boundary. Making the low-level
  `Diagnostic` type depend on the catalog would create a dependency cycle:
  registered rule implementations already depend on diagnostic types.
- Human reports append a plain `Docs: URL` continuation to each known-rule
  diagnostic, including diagnostics carried by analysis errors. No terminal
  escape sequences or network lookups are needed.
- JSON diagnostics gain additive version-1 `documentationUrl` string/null
  metadata. Existing `help.url` remains independently meaningful.
- LSP emits `codeDescription.href` beside the existing rule `code`. VS Code
  and Zed support this standard link target without extension-specific changes;
  their existing diagnostic messages and custom metadata remain unchanged.
- A separate URL field is preferable to replacing `help.url`, which can carry
  user-configured architectural guidance rather than rule documentation.

## Implementation steps

- [ ] Add a pure catalog-backed documentation URL resolver.
- [ ] Integrate human, JSON, and LSP output without changing core detection.
- [ ] Cover every registered rule/page, unknown codes, namespaced IDs, preserved
  custom guidance, analysis-error diagnostics, and real protocol serialization.
- [ ] Update CLI expectations and authoritative JSON/LSP contracts.
- [ ] Run focused tests, `make check`, coverage, npm tests, and actual human,
  JSON, and stdio LSP workflows.
- [ ] Promote the plan to living documentation with the original planning
  record and exact validation results; update the rule-documentation record.
- [ ] Open the dependent diagnostic-link PR after documentation PR #54.

## Validation

Planned checks: focused diagnostic/reporting/LSP test executables, full
`make check`, `make coverage`, `npm test`, CLI smoke checks, and a framed stdio
LSP transcript. Verify that every catalog rule maps to an existing Markdown
page and no unregistered code fabricates a link. Record actual results and
environment blockers as checks run.

## Open questions and remaining work

No unresolved design decisions. The GitHub URLs become live on `main` only
after documentation PR #54 is merged, so the second PR depends on it.
Live graphical editor testing is not available in this workspace; validate the
standard wire format and report that boundary explicitly.
```

### Dated decisions and implementation results

- 2026-11-02: Opened documentation PR #54 before implementing diagnostic links.
  Kept links in a separate branch based on the documentation branch.
- 2026-11-02: Implemented the catalog-backed resolver at output boundaries,
  preserving the low-level diagnostic API and custom help URLs.
- 2026-11-02: Added complete page correspondence, human/JSON/LSP regression
  coverage, and stdio integration expectations. Full checks and native coverage
  passed; changed output modules reached 100% execution-point coverage.
- 2026-11-02: Resolved local npm-suite prerequisites without editing packaging
  code or tests. All 65 npm tests and their coverage gates passed afterward.
