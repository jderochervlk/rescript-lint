# Agent Guidance

## Scope and repository conventions

This repository is an OCaml CLI/library for ReScript linting. Apply this guidance
to first-party code; do not rewrite vendored or generated code. Preserve behavior
during style refactors and avoid unrelated cleanup. Do not introduce frameworks
or dependencies solely to satisfy these design guidelines.

Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup, repository layout, and checks.
`lib/` uses `include_subdirs unqualified`: directories group responsibilities but
do not namespace OCaml modules. Keep rule-specific detection in its rule file and
reuse shared traversal and analysis helpers rather than duplicating AST walks.

## Functional core, imperative shell

Keep domain transformations pure. Isolate filesystem, process, clock, and
transport effects at explicit boundaries. Pass external capabilities and
configuration explicitly instead of relying on hidden global state.

Use [lib/lsp/lsp_document_store.ml](lib/lsp/lsp_document_store.ml) as an example of
immutable state transitions with typed errors, and
[lib/cli/cli_runner.ml](lib/cli/cli_runner.ml) for explicit lint/fix dependencies
and transformations into report data. Follow the boundary in
[bin/main.ml](bin/main.ml), which wires runtime capabilities and prints responses,
and [lib/source/source.ml](lib/source/source.ml), which translates I/O failures.

## Small, composable functions

Give each function one clear responsibility. Extract helpers that name domain
concepts or isolate effects; avoid arbitrary fragmentation and speculative
abstractions.

Target functions below 40 lines, cyclomatic complexity at or below 5, and nesting
no deeper than three blocks. These are review targets, not automatically enforced
checks. Explain exceptions in the change description or a nearby comment when
extraction would harm clarity, such as an exhaustive AST match.

## Immutable data

Prefer immutable records, variants, maps, and sets, and treat inputs as immutable.
Return updated state explicitly when practical. Local mutation is permitted at
effect boundaries, when a library contract requires it, or for a demonstrated
performance benefit. Keep it encapsulated and explain the reason.

Buffers, hash tables, and adapter runtime state are valid tools when justified;
for example, the cache and signal state in `bin/main.ml` belong to its runtime
boundary. Keep such state out of otherwise pure domain transformations.

## Precise types and total behavior

Model domain states with variants and records. Represent absence with `option`
and expected failure with a typed `result`. Match exhaustively; avoid broad
wildcards that conceal missing domain cases. Use partial operations only where
an invariant establishes their preconditions, and make that invariant clear.

## Errors as values

Reserve exceptions for library/runtime contracts and genuinely impossible
invariants. Catch boundary exceptions narrowly and translate expected failures
into contextual typed errors, retaining details such as the filename or URI.
Do not swallow unexpected defects with blanket exception handlers. Use
`Fun.protect` where resources or runtime state need cleanup on every exit path.

## Idiomatic OCaml composition

Use standard library functions such as `List.map`, `List.filter_map`, and folds
when they express intent clearly. Prefer direct pattern matching and recursion
for AST/tree traversal or algorithms when clearer. Preserve tail recursion where
stack safety matters. Do not require pipelines, eta reduction, or combinators
merely for appearance.

## Narrow interfaces

Follow existing `.ml`/`.mli` patterns. Keep implementation details private and
expose only what callers need; use abstract types where representation is private.
Use labeled arguments where they clarify meaning. Reuse existing domain types
and helpers rather than introducing parallel abstractions. Update interfaces
and their contract documentation together with behavior changes.

## Testing and verification

Cover success, failure, and boundary cases, and add focused regression tests for
behavior changes. Run the narrowest relevant check while iterating (`make build`,
`make test`, or a focused `opam exec -- dune runtest <test-directory>`), then run
`make check` before completion. It builds, checks formatting and OCaml lint, and runs tests.
If the environment blocks a check, report the exact blocker.

Run the existing coverage and npm packaging checks in `CONTRIBUTING.md` when the
change affects those areas. Never weaken types, tests, lint rules, or coverage
thresholds to pass. Documentation-only changes should remain documentation-only;
report unrelated failures without changing source code to make the checks pass.

## Required planning and feature documentation

Every implementation task, including bug fixes, refactors, and tooling changes,
must have a repository-owned plan before implementation begins.

1. Create `docs/plans/<descriptive-kebab-case-name>.md` using the
   [plan template](docs/plans/README.md). An existing plan may be extended when
   the task belongs to the same scope.
2. Include `Created` and `Last updated` dates in `YYYY-MM-DD` format. Keep the
   creation date unchanged and update the latter whenever the document changes.
   Include a status and links to relevant GitHub issues when applicable.
3. Record the problem, intended outcome, scope and non-goals, approach, actionable
   implementation steps, and validation criteria. Resolve consequential open
   decisions before implementing the affected steps.
4. Commit the plan before implementation, so the intended work is reviewable in
   Git history. Keep plan changes in version control as the work evolves; do not
   leave plans only in chat, temporary files, or untracked agent notes. This
   requirement does not authorize pushing, merging, or publishing changes.
5. Keep the plan current during implementation: update progress, decisions,
   scope changes, validation results, and remaining work. Distinguish checks
   actually run from checks still planned.
6. As behavior is implemented, turn its plan into living documentation under
   `docs/features/`, following the
   [feature documentation guidance](docs/features/README.md). For a partially
   implemented plan, document delivered behavior there and retain the remaining
   work in the plan, with links in both directions.
7. When the plan is fully implemented, move it to
   `docs/features/<descriptive-kebab-case-name>.md` and rewrite future-tense
   steps and checklists into a description of the actual supported behavior,
   design, usage, limitations, and validation. If a feature document already
   exists, consolidate the plan into it rather than create competing references.
   Preserve the original creation date, update `Last updated`, and repair links
   affected by the move. Git history preserves the original plan.
8. Every later change to that behavior must update its feature documentation in
   the same change. Documentation is part of completion, not a follow-up task.

These requirements apply to new work. Existing documents elsewhere in `docs/`
remain valid references; do not bulk-move historical plans or logs as unrelated
cleanup. Link to existing authoritative contracts rather than duplicating them.

## Verification and handoff

Follow `CONTRIBUTING.md` for development commands. Run checks appropriate to the
change and record exact commands and outcomes in the plan or feature document.
Do not claim unrun tests passed. Keep unrelated workspace changes out of commits.
