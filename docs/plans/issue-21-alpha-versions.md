# Alpha version automation

Created: 2026-10-22
Last updated: 2026-10-22
Status: planned; operational acceptance requires human setup and rollout
Issue: https://github.com/jderochervlk/rescript-lint/issues/21

## Scope and decisions

Use `npm/package.json` as the version authority. Keep the base at `0.1.0`
and channel at `alpha`; count every ordinary merged PR once. Preserve manual
tags, protected npm staging, OIDC stage-only publishing, and per-package 2FA.
Do not introduce a release framework or change branch protection.

Use a committed checkpoint containing source PR IDs and positively identified
automation PR IDs, with an explicit bootstrap commit. Reconcile the complete
merge history since that commit, not just the triggering event. Use GitHub App
identity and an exact owned branch plus checkpoint evidence to identify version
PRs. Serialize automation and compare Git refs before mutation. Build pending
updates from current main, retaining branch history without force pushes.

The privileged workflow will be supplied as an inert template, not deployed.
Enabling it, installing an App, creating secrets, changing repository auto-merge
policy, and the controlled merge rollout require separate human authorization.

## Implementation steps

1. Commit this plan before implementation.
2. Add strict version validation, consistency check, dry-run/updater, isolated
   Dune metadata generation, and prerelease staging guard.
3. Add merge reconciliation model, App-backed adapter, and inert workflow
   template; test retries, identity, interrupted runs, and rapid merges.
4. Add read-only CI checks and focused Node tests. Retain all native gates.
5. Document supported behavior in `docs/features`, keeping this dated record
   and outstanding operational work cross-linked.
6. Run focused tests, `make check`, coverage and npm packaging gates. Commit,
   push, open PR, request actual GitHub Codex review and report pending review.

## Validation criteria

Reject malformed/stable versions and inconsistent source/runtime/metadata
versions before writes. Alpha increments include 9 -> 10 and batches. Dry runs
write nothing; failed validation or Dune generation leaves source untouched.
Reconciliation must account for each eligible merge exactly once and avoid
automation loops. Check tag, source, CLI and alpha dist-tag before staging.
All-target native checks remain in the existing shared workflow.

## Remaining operational acceptance

Human: install narrowly scoped GitHub App (contents and pull requests write),
provide App ID/private-key secret and bot login, authorize template deployment,
enable repository auto-merge without bypassing required checks/reviews, decide
how mandatory human review is fulfilled, and authorize one staging-disabled
controlled merge rollout. No implementation-only claim satisfies acceptance
criteria 1 or the live rollout requirement.
