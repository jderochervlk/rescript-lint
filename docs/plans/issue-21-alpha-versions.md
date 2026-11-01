# Alpha version automation

Created: 2026-10-22
Last updated: 2026-11-01
Status: repairing Windows workflow assertions; activation and live rollout pending
Issue: https://github.com/jderochervlk/rescript-lint/issues/21

## Windows workflow assertion repair (2026-11-01)

PR [#48](https://github.com/jderochervlk/rescript-lint/pull/48) failed the
Windows version-regression step at `7d06da1` in
[job 124910672258](https://github.com/jderochervlk/rescript-lint/actions/runs/41327574440/job/124910672258).
The three new workflow-policy assertions require LF text, but the job log shows
CRLF checkout contents. A local reproduction confirms the unchanged permissions
pattern matches LF and rejects otherwise identical CRLF input.

Normalize CRLF to LF at the test's text boundary and exercise the same complete
policy assertions against both LF and CRLF fixtures on every host. Prefer this
to enforcing checkout line endings through Git configuration or `.gitattributes`:
line endings do not change the workflow's permissions or event semantics.
Keep all existing assertions, workflow configuration, required CI gates,
version policy and release/activation boundaries unchanged.

- [ ] Commit this repair plan before implementation.
- [ ] Normalize test input and run all three workflow contracts against LF and
      CRLF variants; prove the added CRLF cases fail without normalization.
- [ ] Run `node --test test/version/workflow.test.mjs`,
      `node --test test/version/*.test.mjs`,
      `node --test test/version/dune.integration.mjs`, and `make check`.
- [ ] Update the feature documentation and actual validation record, then push
      the normal fast-forward fix to PR #48 and inspect the new hosted checks.

This is a test-only repair. Do not change the publishing workflow, application
code, assertions, coverage thresholds or repository settings to make CI pass.
Local CRLF fixtures do not replace verification of the updated Windows job;
report hosted checks as pending until observed. Coverage and npm packaging
checks are not planned again for unchanged application/packaging code.

## GITHUB_TOKEN rollout revision (2026-11-01)

The maintainer chose to start with the built-in `GITHUB_TOKEN`, without a
custom GitHub App, private key, or personal access token. This supersedes the
App provisioning requirement in the historical activation and implementation
records below. Prepare the revised workflow on the existing feature branch;
landing, opt-in, repository setting changes, and releases remain separate actions.

### Intended outcome and decisions

Use the automatic repository token with Contents write and Pull requests write
only on the reconciliation job. Keep ordinary CI read-only. Remove the App
token action, App variables/secrets, and configurable bot login. Use the fixed
`github-actions[bot]` identity plus the existing exact branch/repository/base
and registered PR ID checks; do not weaken positive automation ownership.
Require the adapter to run in GitHub Actions on main with a token.

Keep alpha counting, the checkpoint baseline, trusted-main checkout, draft
registration, non-force updates, auto-merge requests and required checks intact.
GitHub's current documentation says PR events created with `GITHUB_TOKEN`
start CI in an approval-required state. A maintainer can select **Approve
workflows to run**; do not claim unattended CI or bypass that approval.
Token-originated pushes and PR closed events do not start follow-up workflows.
Verify the post-merge no-op with manual dispatch, not an assumed closed event.
Keep manual tags and OIDC npm staging/2FA unchanged.

Initial read-only inspection found `can_approve_pull_request_reviews=false`. GitHub
documents that this is the **Allow GitHub Actions to create and approve pull
requests** setting, so enabling it is a separate administrator prerequisite
even with job-level Pull requests write. Do not change it without explicit
authorization. The automation itself will not submit approval reviews.

The maintainer enabled that setting on 2026-11-01. Read-only verification at
16:14 UTC returned `can_approve_pull_request_reviews=true`, while default
workflow permissions remain `read`. No repository variables are configured,
so `VERSION_AUTOMATION_ENABLED` remains unset and the workflow stays opted out.

### Implementation and validation

- [x] Commit this revised plan before implementation (`ff6ded3`).
- [x] Replace App authentication and hard-coded credential requirements with
      the built-in token and fixed GitHub Actions identity.
- [x] Cover missing token/context, no-App success, positive ownership,
      PR-creation denial/retry, interrupted runs, and merge/no-loop behavior.
- [x] Update living feature, release and contributor guidance with the single
      repository permission prerequisite, workflow-run approval, and manual retry.
- [x] Run version tests, real-Dune integration, workflow lint, `make check`,
      coverage, release guards, and local npm packaging/rebuild gates.
- [x] Record actual outcomes and live rollout limitations. Keep #21 open;
      the original fully unattended acceptance is not established by this phase.

### GITHUB_TOKEN implementation results (2026-11-01)

The workflow and adapter now use only the built-in token, with write
permissions scoped to the reconciliation job. Removed the App token action,
key/client-ID/bot-login configuration, and App-only adapter guard. The adapter
requires GitHub Actions on main, uses fixed `github-actions[bot]` ownership,
and retains the existing checkpoint, draft registration, non-force update,
and required-check/auto-merge protocol. PR bodies explain workflow-run approval.

Validation passed on Linux x64 with Node 24.16.0 and the existing
OCaml 5.5.0/Dune 3.24.2 development switch:

- `node scripts/version/cli.mjs check`;
  `node --test test/version/*.test.mjs` (18 tests);
  `node --test test/version/dune.integration.mjs` (3 tests).
  New regressions cover built-in-token setup, missing token/context,
  shared-bot ownership spoofing, unexpected branch committers, PR creation
  denied by repository policy and safe retry, and workflow permission boundaries.
  Existing interrupted-mutation, duplicate, rapid-merge and no-loop tests pass.
- `actionlint .github/workflows/*.yml` with checksum-verified actionlint 1.7.12.
  ShellCheck is not installed. A separate YAML-structure check confirmed
  trusted-main checkout, read-only defaults, job-scoped writes, serialization,
  and direct built-in-token wiring. These are local checks, not hosted execution.
- `make check` (488 OCaml sources, zero lint findings) and
  `make coverage` (96.61% overall, all existing per-file gates intact).
- `opam exec -- dune build --profile release @install`;
  `node scripts/version/cli.mjs release`; `npm run prepare:licenses`;
  `npm test` (65 tests; 100% npm coverage); `npm run test:rebuild`;
  `npm run pack:native`; `npm run test:package`.
- `git diff --check` and relative documentation links.

Validation used `OPAMSWITCH=$PWD` with the existing ignored `_opam` link and
`DUNE_ROOT=$PWD` to select this nested worktree. No checks or policies were
weakened. No App, PAT, npm token, or new secret was configured.

### Remaining live acceptance

- [ ] Review and separately authorize landing the workflow/adapter change.
- [ ] Authorize the maintainer-assisted rollout under the existing branch rules,
      then set `VERSION_AUTOMATION_ENABLED=true` and dispatch from main.
- [ ] Observe the generated version PR, approve its CI runs where required, and
      verify all five native targets and auto-merge under the required checks.
- [ ] Manually reconcile after merge to observe the no-op and exercise a
      controlled source merge/rapid-merge retry without staging.

The repository PR-creation prerequisite is now satisfied, but no live
`GITHUB_TOKEN` reconciliation has run. Local tests do not establish hosted
permissions, workflow approval, auto-merge, or full issue acceptance.
No merge, tag, staging, or publication was performed. #21 remains open.

## Historical App-based preparation

The following records describe the superseded App-based approach, not current
setup requirements.

## Activation preparation (2026-11-01)

The repository implementation landed in PR #42. The maintainer now requests
that the automation be set up and ready to use. Prepare deployment on a feature
branch; this does not authorize landing it, creating release tags, or publishing.
The original implementation plan and dated decisions remain below.

### Problem and intended outcome

The reconciliation adapter and native CI gates already exist, but the workflow
is still an inert template. No App variables or private-key secret are configured.
Make the repository side deployable with an explicit operator opt-in and clear,
secure one-time setup and rollout instructions.

### Scope and approach

Promote the existing template into `.github/workflows/alpha-versions.yml`,
removing the competing template. Require `VERSION_AUTOMATION_ENABLED=true` and
trusted main before the job runs. Validate required configuration before
toolchain setup and verify the configured bot against the token action's App
identity before any GitHub mutations. Reuse the reconciliation protocol,
checkpoint baseline, native gates, and read-only default workflow permissions.
Use a reviewed SHA-pinned token action compatible with Node 24.

Keep repository rules unchanged. Recommend retaining the existing eventual
reconciliation policy: a source merge racing a version PR is counted on the
next run. Operator approval of that policy and unattended auto-merge remains
required before opt-in. A GitHub App must be installed on this repository only,
with Contents write and Pull requests write; its key belongs only in GitHub's
Actions secret store. No npm permission or branch-protection bypass is needed.

### Implementation steps

- [x] Commit this activation plan before implementation (`4e2fa14`).
- [x] Promote and guard the workflow; validate configuration and App identity.
- [x] Update the living feature guide, release guide, and contributor guidance
      with exact setup, enable/disable, retry, and staging-disabled rollout steps.
- [x] Validate workflow syntax, missing/configured settings and bot identity,
      version/reconciliation regressions, and the normal repository checks.
- [x] Record actual results and remaining human setup. Leave #21 open until
      App-backed CI, auto-merge, and the following no-op are observed live.

### Validation and remaining work

Run `node scripts/version/cli.mjs check`,
`node --test test/version/*.test.mjs`, real-Dune integration tests, workflow
lint, and `make check`. Run coverage and Linux native packaging/rebuild gates
where the available toolchain permits; hosted CI must establish the other four
targets. Test the workflow's actual configuration and identity shell steps with
missing values and mismatched identities without real credentials.

Read-only inspection found auto-merge and squash enabled, six required checks,
zero required approving reviews, and non-strict up-to-date-branch policy.
Do not change these settings or opt in during preparation. App provisioning,
explicit rollout authorization, landing the workflow, and a controlled merge
remain external acceptance requirements, not results of local tests.

### Activation preparation results (2026-11-01)

Promoted the workflow with opt-in/ref/event guards, fail-fast configuration,
repository/permission-narrowed App token, and App slug/bot verification.
The token action is SHA-pinned v3.3.0 on Node 24 and uses
`VERSION_APP_CLIENT_ID`, not the old template's App ID variable. The checkpoint
baseline, adapter, CI gates, source version, release workflow, and repository
settings are unchanged.

Passed on Linux x64 with Node 24.16.0 and the existing OCaml 5.5.0/Dune 3.24.2
development switch:

- `node scripts/version/cli.mjs check`;
  `node --test test/version/*.test.mjs` (12 tests);
  `node --test test/version/dune.integration.mjs` (3 tests).
- `actionlint .github/workflows/*.yml` using checksum-verified actionlint 1.7.12.
  ShellCheck is not installed. Instead, an ad-hoc harness extracted and ran the
  actual configuration/identity scripts with Actions' Bash invocation: 11 cases
  passed, including unset/empty settings and mismatched/missing App identity,
  without printing a fake key. Nine job-condition cases passed in local Node
  expression evaluation, including manual dispatch without a PR payload.
  This is not a GitHub-hosted event or expression-engine test.
- `make check` (488 OCaml sources, zero lint findings) and
  `make coverage` (96.61% overall; every file meets the existing gate).
- `opam exec -- dune build --profile release @install`;
  `node scripts/version/cli.mjs release`;
  `npm run prepare:licenses`; `npm test` (65 tests, 100% npm coverage);
  `npm run test:rebuild`; `npm run pack:native`; `npm run test:package`.
- `git diff --check` and relative links in changed documentation.

Environment corrections: the first `make check` discovered the enclosing
primary checkout rather than this nested worktree; setting `DUNE_ROOT=$PWD`
fixed root selection without changing the Makefile. Early npm tests lacked
the prepared bundle and selected the wrong/local-missing switch. Prepared the
bundle, selected the existing development switch, and added an ignored local
`_opam` link because the CLI fixture explicitly selects this repository's
switch. The final full npm/packaging sequence above passes unchanged.

Read-only inspection also confirms Actions is enabled, allows the pinned App
action, and uses read-only default workflow permissions without bot review
approval permission. No App-backed workflow run, hosted native matrix, merge,
tag, npm staging, or publication was performed. The other four native targets
and all live rollout observations remain pending. #21 stays open.

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

### Integrate hosted diagnostics and current main (2026-10-22)

Merge main through PR #45 (`6a83ab8`) normally once to include the landed
failure-only Opam observer and intervening CLI/hook changes. Preserve the
version-consistency/unit-test step, separate post-dependency real-Dune tests and
runtime release guards alongside the observer. If the shared workflow conflicts,
resolve by retaining both sets of steps; do not modify setup pins, cache policy,
fatal gates, signature checks or permissions. Retain the checkpoint baseline and
human-only activation/release boundaries.

Validate the combined tree with observer and version/Dune tests, exact
`make check`, coverage and all local npm packaging/rebuild gates, then push
normally and request current-head Codex review and the complete native matrix.
If setup fails, use the failure-only observer's actual runner evidence before
considering further recovery. Do not retry stale runs or introduce source churn
only to trigger CI.

Integration result: the only conflict was adjacent shared-workflow steps;
retained the failure-only observer followed by version consistency/unit tests,
with the real-Dune tests still after dependency installation. Observer/version/
Dune tests, `make check`, `make coverage` (96.63% project), release build/runtime
guard, `npm run prepare:licenses`, `npm test` (58 passing; 100% npm coverage),
`npm run test:rebuild`, `npm run pack:native` and `npm run test:package`
passed on the integrated Linux x64 tree. Current-head hosted CI and Codex review
remain pending; these local results do not establish live automation rollout.

### Codex revision plan (2026-10-22)

Actual Codex rereview requested a more auditable reconciliation boundary.
Split credential/snapshot loading, owned-branch verification, freshness checks,
Git-tree commits, draft registration and PR readiness/auto-merge into focused
helpers. Keep `run` as short orchestration and preserve the existing effect
ordering, non-force updates, checkpoint protocol and failure behavior. Run
accepted-mutation interruption tests and all other local gates, then request
another actual Codex review and exact-head five-target CI before landing.

Another finding asserts that `*.test.mjs` includes `dune.integration.mjs`.
Verify the actual glob expansion and hosted ordering before changing anything:
the integration filename intentionally lacks the `.test.mjs` suffix and has
its own step after dependency installation. Reply with evidence; do not weaken
future unit-test discovery to accommodate an incorrect glob assumption.

Revision progress: named phases implemented with explicit branch-head returns;
all 15 focused tests pass, including interruption after each accepted mutation.
Verified shell and Node glob expansion returns only the two `.test.mjs` unit
files, not `dune.integration.mjs`; replied with that evidence and resolved the
incorrect early-integration-test finding without changing CI discovery.

Repository validation on 2026-10-22: focused script tests, real Dune metadata
generation, `make check`, `make coverage`, release build/runtime guard,
`npm run prepare:licenses`, `npm test` (58 tests, 100% npm coverage),
`npm run test:rebuild`, `npm run pack:native` and `npm run test:package`
passed locally on Linux x64 glibc. The pinned parser submodule was restored
without changing the gitlink. Validation used the existing read-only development
switch through environment selection and an ignored local `_opam` link.
Other native targets require the existing GitHub CI matrix; live App behavior
and rollout are not established by these local checks.

PR [#42](https://github.com/jderochervlk/rescript-lint/pull/42) was opened after
normal publication through existing SSH credentials. Codex review of the first
implementation commit completed with no findings. The first native matrix
exposed a Windows CRLF-template metadata regression despite successful toolchain
setup; it was reproduced with real Dune and fixed narrowly with LF template
normalization and LF/CRLF/substantive-drift tests. Current-head review and
five-target CI must pass before a separately authorized landing. The
[feature document](../features/alpha-version-automation.md#windows-metadata-regression-2026-10-22)
records the root cause and correction of the earlier installer hypothesis.

Repository behavior and current setup instructions are maintained in the
[living feature document](../features/alpha-version-automation.md). The dated
plan above is the historical implementation record, not a rollout claim.

Read-only inspection on 2026-10-22 found auto-merge already enabled and squash
allowed. Main is protected through a repository ruleset, not legacy branch
protection; six native checks are required and zero approving reviews, but the
strict/up-to-date check policy is false. No settings were changed.

Human: install narrowly scoped GitHub App (contents and pull requests write),
provide App ID/private-key secret and bot login, authorize template deployment,
authorize use of auto-merge and resolve the up-to-date-branch policy without
bypassing required checks/reviews, decide
how mandatory human review is fulfilled, and authorize one staging-disabled
controlled merge rollout. No implementation-only claim satisfies acceptance
criteria 1 or the live rollout requirement.
