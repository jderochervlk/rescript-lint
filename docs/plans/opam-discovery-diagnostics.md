# Opam release discovery diagnostics

Created: 2026-10-22
Last updated: 2026-10-22
Status: Planned
Issue: none
Feature documentation: pending

## Problem and intended outcome

Hosted setup-ocaml intermittently reports no compatible stable Opam release.
Collect sanitized same-runner, same-token evidence without changing setup policy.

## Scope and non-goals

Add failure-only observation to the shared npm workflow and dependency-free Node
fixture tests. Do not change action pins, compiler, installer, signatures,
platforms, caches, protected gates, or release approval boundaries.

## Approach and decisions

Give setup a step id and run one authenticated default releases request only
after setup fails. Log allowlisted bounded response metadata and release fields;
never log raw errors, bodies, request options, or credentials. A subsequent
request cannot establish the exact body observed by the external action.
Prefer failure-only observation over preflight to avoid extra successful-job
requests. Observation failure must remain distinct from the original fatal setup.

## Implementation steps

- [ ] Implement a bounded sanitized observer and empty/malformed/error tests.
- [ ] Wire failure-only observation with the same github.token as setup.
- [ ] Document limitations, run checks, open PR, request @codex review.
- [ ] Obtain five-target CI evidence; hold merge pending parent slot approval.

## Validation

Planned: node --test scripts/ci/opam-discovery.test.mjs; exact diagnostic command
with local fixtures; make check using the existing read-only Opam switch.
Hosted CI must preserve failed setup status and existing five-target gates.
Record actual outcomes separately in living documentation.

## Open questions and remaining work

No root cause is established. Do not retry or propose a remedy without new
evidence. Actual merge requires parent approval.
