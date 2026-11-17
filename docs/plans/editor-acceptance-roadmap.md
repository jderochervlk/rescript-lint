# Editor acceptance and readiness

Created: 2026-11-17
Last updated: 2026-11-17
Status: In progress
Issue: none
Feature documentation: [public release audit](../features/public-release-audit.md)

## Problem and intended outcome

The editor documentation mixes implemented protocol behavior, stale platform
assumptions, historical sequencing, and manual acceptance still not performed.
The recorded LSP benchmark is also historical, leaving current latency uncertain.
Make readiness claims traceable to executable checks or explicitly identified
manual/external-host gates without claiming unavailable validation.

## Scope and non-goals

Review the LSP/performance documents, existing benchmark and transcript tests,
and package/editor integration contracts. Run the reproducible benchmark where
the available toolchain allows. Correct editor readiness and platform claims,
and add a focused in-repository acceptance check only for a demonstrated gap.
Record the macOS Yarn installation verification gap in the release audit.

Do not implement later roadmap features, quick fixes, multi-root support, semantic
fixes, or changes to external integration repositories. Do not claim GUI/macOS
acceptance absent the required host.

## Approach and decisions

Treat repository protocol tests and client installation/GUI acceptance as
separate evidence. Existing automation consists of in-process protocol/runtime
tests, a real-process CLI smoke test, and the LSP benchmark harness. Do not build
a parallel harness; add checks only when current automation misses a concrete,
locally addressable contract. Record machine, runtime, workload, binary
identity, and exact results for any new benchmark run; do not compare across
unlike baselines.

## Implementation steps

- [x] Inspect current LSP docs, benchmark, tests, and package contracts.
- [x] Attempt the current reproducible benchmark and retain exact result or blocker.
- [x] Correct delivered/pending editor, platform, and sequencing documentation.
- [x] Record the Yarn/macOS consumer verification gap in the release audit.
- [x] Run available documentation checks and record executable-check blockers.
- [x] Run `make check` and document both the default and available-switch outcomes.

## Validation

Benchmark attempt:
`DUNE_ROOT="$PWD" OPAMSWITCH=/home/josh/Dev/rescript-linter opam exec -- dune build scripts/benchmarks/benchmark_lsp.exe bin/main.exe`
could not build because the existing deleted `vendor/rescript` directory is
required by parser copy rules. No benchmark numbers were collected.

Run focused LSP tests and `make check` if source changes are needed. State exact
commands, host constraints, and any acceptance that remains unrun.

Actually run:

- `git diff --check`: passed.
- `make check`: failed before Dune with `opam exec -- dune build @all @check @fmt`
  reporting `[ERROR] Command not found 'dune'` in the default switch.
- `DUNE_ROOT="$PWD" OPAMSWITCH=/home/josh/Dev/rescript-linter make check`:
  failed because the existing deleted `vendor/rescript` content is required by
  parser copy rules. `vendor/parser/{ext,ml,syntax}/dune` could not find their
  source directories.
- The benchmark build attempt above failed before execution because the parser
  submodule content is absent. No LSP tests completed; the same missing vendor
  source blocks compiling them in this worktree.

## Open questions and remaining work

Live editor acceptance may require a GUI-capable Zed host and platform-native
machines. The currently referenced upstream Zed extension does not include the
adapter described in this document; implementation and an exact development
checkout/ref are prerequisite external work. Confirm whether the public Yarn/macOS
ARM64 reproduction has been completed before closing the release issue; do not
infer it from registry availability or Linux package tests.
