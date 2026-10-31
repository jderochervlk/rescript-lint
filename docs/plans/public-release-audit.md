# Public release audit and recovery

Created: 2026-10-31
Last updated: 2026-10-31
Status: Planned
Issue: https://github.com/jderochervlk/rescript-lint/issues/30
Feature documentation: pending

## Problem and intended outcome

The public alpha.3 launcher references a Windows version absent from npm.
Existing staging order and native-before-launcher approval instructions already
exist. Recovery currently lacks an explicit path for an already-public launcher.

## Scope and non-goals

Add a read-only public release audit and an actionable recovery path. Do not
publish, stage, approve, change versions, drop targets, or alter release permissions.

## Approach and decisions

Audit the explicitly selected public launcher manifest, not local source versions.
Resolve every exact optional dependency against public npm; fail closed on
registry errors. Keep the existing manual npm 2FA boundary.

## Implementation steps

- Add an injectable registry audit and CLI with focused Node tests.
- Document recovery choices and remaining human actions.
- Preserve this plan in feature documentation on completion.

## Validation

Run focused Node tests, npm test, the audit against alpha.3, version consistency,
and make check where feasible. An alpha.3 audit must fail naming Windows.

## Open questions and remaining work

Private pending stages and reviewed artifacts require maintainer inspection.
Only a maintainer can choose completion of alpha.3 or a fresh corrected release.
