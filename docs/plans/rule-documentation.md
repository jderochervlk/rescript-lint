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
