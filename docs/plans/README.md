# Implementation plans

Created: 2026-10-21
Last updated: 2026-10-22

Plans describe intended work before implementation. The required lifecycle is
defined in [AGENTS.md](../../AGENTS.md). Commit each plan before implementing it,
then maintain it as scope, decisions, and progress change.

Use a descriptive kebab-case filename, such as `custom-hook-recognition.md`.
Dates belong in the document metadata, not just in Git history.

## Plan template

Copy the following into a new plan and replace all placeholders, including dates:

```markdown
# <Task title>

Created: YYYY-MM-DD
Last updated: YYYY-MM-DD
Status: Planned
Issue: <issue link, or none>
Feature documentation: <link once implemented behavior is documented, or pending>

## Problem and intended outcome

<What needs to change, why, and what success looks like.>

## Scope and non-goals

<Included behavior and explicit boundaries.>

## Approach and decisions

<Relevant existing architecture, chosen approach, alternatives and tradeoffs.>

## Implementation steps

- [ ] <Concrete, reviewable step.>
- [ ] <Tests and documentation updates.>

## Validation

<Acceptance criteria and exact planned checks. Record actual commands and
outcomes separately as they run; identify checks not run and why.>

## Open questions and remaining work

<Unresolved decisions, blockers, or none.>
```

Use `In progress` or `Blocked` as appropriate while retaining unfinished work.
As parts ship, document their actual behavior in [features](../features/README.md)
and cross-link the documents. On completion, move or consolidate the plan into
feature documentation; do not leave a completed plan as a second, stale source
of truth. Before rewriting or consolidating, copy the original committed plan's
contents and dated decisions and scope changes into the feature document's
historical planning record. Retain that record in the final tree, independently
of commit history, so it survives squash merges.

When creating a feature document from a plan, preserve the plan's `Created` date.
When consolidating into an existing feature document, preserve that document's
`Created` date and keep the later plan's dates in its planning record. Update
`Last updated` and fix links affected by the move.
