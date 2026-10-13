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
`make check` before completion. It builds, checks formatting, and runs tests.
If the environment blocks a check, report the exact blocker.

Run the existing coverage and npm packaging checks in `CONTRIBUTING.md` when the
change affects those areas. Never weaken types, tests, lint rules, or coverage
thresholds to pass. Documentation-only changes should remain documentation-only;
report unrelated failures without changing source code to make the checks pass.
