# Living feature documentation

Created: 2026-10-21
Last updated: 2026-10-22

This directory describes implemented behavior, including fixes, internal
architecture, and tooling. Documents evolve from committed
[implementation plans](../plans/README.md), as required by
[AGENTS.md](../../AGENTS.md).

Feature documentation must describe what is true now, not merely retain a
completed checklist. Update it whenever the documented behavior changes, in the
same change as the implementation.

## Feature document template

```markdown
# <Feature title>

Created: YYYY-MM-DD
Last updated: YYYY-MM-DD
Status: Implemented
Issue: <issue link, or none>

## Purpose and supported behavior

<The implemented contract and intended use.>

## Usage

<Examples, configuration, or the developer workflow where relevant.>

## Design and boundaries

<Key decisions, architecture, limitations, and unsupported cases.
Link to existing authoritative references instead of duplicating them.>

## Validation

<Relevant tests and checks, exact commands actually run and their outcomes,
and any checks not run. Keep historical evidence distinct from current guarantees.>

## Historical planning record

### <Plan title>

Plan created: YYYY-MM-DD
Plan last updated: YYYY-MM-DD

<Preserve the original committed plan's contents, followed by dated decisions
and scope changes. For later consolidated plans, append a separate entry with
its own title and dates. This is historical intent, not the current contract.>
```

When promoting a plan to a new feature document, preserve the plan's `Created`
date. When consolidating into an existing feature document, retain that document's
`Created` date and record the later plan's dates in its historical planning record.
Update `Last updated` whenever editing the document.

Before rewriting or consolidating a completed plan, preserve its original committed
contents and dated decisions and scope changes in the historical planning record.
Keep this record in the final tree: commit history alone does not preserve the
original plan through squash merges. The supported-behavior sections remain the
authoritative current reference; the historical record is not an active checklist.

For incremental delivery, use `Partially implemented`,
document only delivered behavior as supported, and link to the active plan for
remaining work. Do not present unimplemented proposals as available features.
