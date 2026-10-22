# Opam release discovery diagnostics

Created: 2026-10-22
Last updated: 2026-10-22
Status: Implemented; hosted evidence pending
Issue: none

## Supported behavior and usage

The shared npm workflow gives setup-ocaml an id and runs
`node scripts/ci/opam-discovery.mjs` only after that step fails. It makes one
authenticated default-page request to the public GitHub Opam releases endpoint
with the same `github.token` used by the action's default input. It logs HTTP
status, allowlisted bounded headers, release count/tags, and matching platform
binary/signature availability. It does not duplicate semver interpretation;
tags are evidence for the pinned action's stable `<2.7.0` selection.

The script limits body consumption to 2 MiB, release/asset counts, and external
text length. It redacts reflected credentials and never prints raw errors,
request options, arbitrary bodies, or non-allowlisted headers. Transport,
malformed response, HTTP failure, and missing token observations are distinct.
The observer does not retry or affect installer selection. Setup remains fatal;
no gate, pin, signature policy, platform, cache, or release approval changes.

This is a subsequent request, not instrumentation inside the action. A healthy
response after setup failure cannot prove the action received an empty list,
nor establish a root cause. Diagnostic failure is not a setup outcome.

## Validation and remaining work

- `node --test scripts/ci/opam-discovery.test.mjs`: eight tests passed after
  addressing Codex feedback to retain received metadata across all body failures.
- `node scripts/ci/opam-discovery.mjs`: emitted `missing-token`, no network call.
  Authenticated transport is tested with an injected fixture, not a desktop token.
- `OPAMSWITCH=/home/josh/Dev/rescript-linter DUNE_ROOT="$PWD" make check`:
  passed after restoring the pinned vendor checkout from the existing local
  repository. Initial attempt failed because that checkout was empty.
- Hosted five-target CI and @codex review remain pending. No root remedy is
  claimed. Merge remains held for parent slot approval.
- Publication blocked on 2026-10-22: normal `git push -u origin
  ci/opam-discovery-diagnostics` was rejected because the current OAuth App
  lacks `workflow` scope. No PR was created and no hosted run or review was
  requested. No authentication/settings changes or alternate transport attempted.
- Subsequently, parent authorized the existing SSH transport to the same
  repository; the normal push succeeded without credential or settings changes.
  [PR #45](https://github.com/jderochervlk/rescript-lint/pull/45) requested actual
  `@codex review`. Run `39869602897` reached successful setup on Linux x64,
  Linux ARM64, Windows x64 and macOS ARM64; observers were skipped. macOS x64
  setup and final matrix gates were still pending at observation time.
- Codex finding `4354490478` identified loss of HTTP classification/headers for
  non-JSON error bodies. The observer now cancels error bodies without decoding
  and preserves HTTP status and allowlisted headers; fixtures cover HTML and
  oversized HTTP 503 bodies.
- Follow-up Codex findings `4354532446` and `4354532453` exposed cancellation
  errors overriding HTTP metadata and malformed successful bodies losing headers.
  Received sanitized metadata now survives every body outcome; HTTP cancellation
  is best-effort cleanup only. Errored-stream and malformed-success fixtures
  exercise the common rule.

## Historical planning record

The following is the original committed plan (2026-10-22), retained as
historical intent rather than the current behavior contract.

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
