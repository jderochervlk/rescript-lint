# Automatic alpha staging

Created: 2026-11-02
Last updated: 2026-11-02
Status: Workflow integration delivered locally; validation and operational rollout pending
Issue: https://github.com/jderochervlk/rescript-lint/issues/21
Plan: [Automatic alpha release staging](../plans/automatic-alpha-staging.md)

## Local implementation behavior

The [release workflow](../../.github/workflows/release.yml) defines the main-push
and approximately 15-minute scheduled reconciliation path. Automatic staging
requires `ALPHA_STAGING_AUTOMATION_ENABLED=true`; it defaults off. The selector
uses trusted main, the registered alpha-version PR checkpoint, canonical merge
history, and a reviewed cutoff to choose the oldest pending release. A no-candidate
result skips native build jobs. Manual build-only dispatch remains separate from
staging, and tag/manual staging paths select the same registered source identity.

The selected source SHA and expected version are passed to
[`npm.yml`](../../.github/workflows/npm.yml). Target discovery, native builds,
version checks, and staging data are read from that immutable source. Only
artifacts produced in the same release workflow run are downloaded. Staging
uploads the five native packages before the launcher.

Staging attempts are persisted in the data-only
`automation/alpha-staging-state` branch. A run writes and rereads its immutable
attempt, records each accepted package in order, and marks completion only after
all six are accepted. Git commits have the observed ledger tip as sole parent;
branch updates use `force: false`. Completed duplicates are no-op outcomes.
Incomplete attempts, unknown upload results, missing/corrupt state, conflicting
identity, or ambiguous ref writes require maintainer inspection and cannot be
automatically retried. The ledger is not a substitute for npm stage inspection.

## Operational status and safeguards

Automatic staging is intentionally not enabled. No remote ledger branch was
created, no repository or npm settings were changed, and the existing GitHub
`npm` environment reviewer gate and npm publication 2FA approval remain intact.
The alpha.22 run
[41534711436](https://github.com/jderochervlk/rescript-lint/actions/runs/41534711436)
staged all six packages after five native builds; alpha.22 and earlier versions
are operator-owned and must be excluded by the separately reviewed cutoff.
This record does not establish that npm publication approval occurred.

Before rollout, maintainers must audit existing staged/public versions; choose
and confirm the cutoff; verify the six stage-only npm trusted publishers; establish
data-branch write/deletion protection; explicitly initialize the ledger once;
and decide whether to remove the GitHub `npm` environment reviewer gate. The
environment currently has no deployment-branch policy. Before removing its
reviewer, restrict deployments to `main` and matching canonical release tags,
and verify the exact GitHub workflow/environment binding for all six npm
publishers. Keep the gate if unattended staging is not yet authorized. Never
reset or recreate the ledger as a retry technique.

The operator-only `npm run ledger:alpha-staging -- inspect` and
`bootstrap --confirm-bootstrap --cutoff=N` commands are documented in the
[release runbook](../development/RELEASING.md). Do not execute bootstrap without
the separate rollout authorization.

## Validation and recovery

See the [implementation plan](../plans/automatic-alpha-staging.md) for exact
local checks, known validation blockers, and remaining operational steps.
Review the ledger and all six `npm stage list` results after an interrupted or
ambiguous upload. Do not replay alpha.22 or any earlier operator-owned version.
Expired artifacts or an unknown accepted upload require explicit maintainer
recovery, potentially with a new version; uploads cannot be rolled back.
