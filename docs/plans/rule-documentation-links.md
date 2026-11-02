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
