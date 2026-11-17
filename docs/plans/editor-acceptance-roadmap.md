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
separate evidence. Prefer the existing real-process transcript tests and LSP
benchmark over a parallel harness; add checks only when current automation misses
a concrete, locally addressable contract. Record machine, runtime, workload,
binary identity, and exact results for any new benchmark run; do not compare
across unlike baselines.

## Implementation steps

- [ ] Inspect current LSP docs, benchmark, tests, and package contracts.
- [ ] Attempt the current reproducible benchmark and retain exact result or blocker.
- [ ] Correct delivered/pending editor, platform, and sequencing documentation.
- [ ] Record the Yarn/macOS consumer verification gap in the release audit.
- [ ] Run appropriate documentation and executable checks; update this plan.

## Validation

Run the documented benchmark with a frozen release binary if available. Run
focused LSP tests and `make check` if source changes are needed. State exact
commands, host constraints, and any acceptance that remains unrun.

## Open questions and remaining work

Live editor acceptance may require a GUI-capable Zed host and platform-native
machines. Confirm whether the public Yarn/macOS ARM64 reproduction has been
completed before closing the release issue; do not infer it from registry
availability or Linux package tests.
