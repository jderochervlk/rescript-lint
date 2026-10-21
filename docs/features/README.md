# Living feature documentation

Created: 2026-10-21
Last updated: 2026-10-21

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
```

Preserve the plan's `Created` date when promoting it and update `Last updated`
whenever editing it. For incremental delivery, use `Partially implemented`,
document only delivered behavior as supported, and link to the active plan for
remaining work. Do not present unimplemented proposals as available features.
