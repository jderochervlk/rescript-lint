# Automatic alpha release staging

Created: 2026-11-02
Last updated: 2026-11-05
Status: Staging opt-in removed; full check blocked by local submodule setup
Issue: https://github.com/jderochervlk/rescript-lint/issues/21
Feature documentation: [Automatic alpha staging](../features/automatic-alpha-staging.md)

## Remove the staging opt-in flag (2026-11-05)

Maintainer feedback removes the separate
`ALPHA_STAGING_AUTOMATION_ENABLED` switch. Main pushes and scheduled sweeps
should reconcile automatically when the workflow is deployed, rather than
silently skipping because a repository variable is unset or false.

Scope and decisions:

- Remove this flag from the selector guard and concurrency classification.
  Keep repository/ref/event restrictions and separate build-only diagnostics.
- Retain `ALPHA_STAGING_CUTOFF`, the durable ledger, artifact verification,
  GitHub environment protections, and npm 2FA publication approval. The version
  reconciler's separate `VERSION_AUTOMATION_ENABLED` switch is unchanged.
- Missing or invalid cutoff/ledger configuration must still fail closed before
  native builds or uploads. Removing the flag does not authorize setup, landing,
  workflow dispatch, settings changes, or publication.
- Document GitHub's workflow disable/cancel controls for operational pauses;
  do not replace the removed switch with another custom enablement flag.

Implementation steps:

- [x] Remove the workflow opt-in guard while retaining staging serialization.
- [x] Exercise the actual selector and concurrency expressions without a
  variables context, including automatic triggers and rejected refs/events.
- [x] Update living feature, release, contributor, and rollout documentation;
  retain the original committed plan unchanged in the historical record.
- [x] Run focused workflow/version tests, actionlint, and `make check`; record
  actual results separately from earlier implementation validation.

Revision validation:

- The new selector/concurrency regressions first failed against the old guards
  because they required a `vars` context.
- Passed
  `node --test test/npm/alpha-staging-workflow.test.mjs test/version/*.test.mjs`
  (51 tests, including 5 workflow checks).
- Passed checksum-verified actionlint 1.7.12 on `.github/workflows/*.yml`.
- Passed `git diff --check`, document dates/47 local links, preservation of the
  original committed plan, and the unchanged version-reconciliation workflow.
- Attempted
  `OPAMSWITCH=/home/josh/Dev/rescript-linter DUNE_ROOT="$PWD" make check`.
  It stopped because `vendor/rescript/compiler/ext`, `compiler/ml`, and
  `compiler/syntax/src` are absent from this checkout. The normal
  `git submodule update --init vendor/rescript` setup failed because the target
  directory already exists and is nonempty. No vendor files were removed,
  overwritten, or committed to force the check through.
- Full npm coverage, packaging, and rebuild checks were not rerun for this
  workflow-guard/test/documentation revision; production packaging code is
  unchanged. Their earlier results below remain dated implementation evidence.

No remote configuration, ledger bootstrap, workflow dispatch, or publication
was performed. Deployment and operational setup remain separately authorized.

### PR preparation (2026-11-05)

The maintainer authorized publishing the implementation branch and opening a PR,
not merging or changing rollout settings. SHA/version pinning was already
implemented; review clarification now explains the immutable source inputs,
their version assertion, and why trusted verification tooling uses a separate
hidden checkout.

Before submission, the integrated branch passed
`node --test test/npm/alpha-staging-*.test.mjs test/npm/stage-release.test.mjs test/npm/release-preflight.test.mjs test/version/*.test.mjs`
(94 tests), checksum-verified actionlint 1.7.12 on all workflows, documentation
link/history checks, and `git diff --check`. Current `main` is an ancestor of the
branch. The previously recorded local submodule blocker remains; full native and
packaging gates were not rerun for this documentation clarification.

## Problem and intended outcome

Merges currently automate version reconciliation, not release staging.
The [version workflow](../../.github/workflows/alpha-versions.yml) opens and
requests auto-merge for a registered version PR. The
[release workflow](../../.github/workflows/release.yml) only responds to release
tags or manual dispatch. Its staging job also requires approval of GitHub's
`npm` environment before npm uploads can begin.

Observed on 2026-11-02:

- [Version PR #56](https://github.com/jderochervlk/rescript-lint/pull/56) merged
  `0.1.0-alpha.22` as `5ba8b9ec63fb3dd71f1031e6f368747b438ff141`.
  No post-merge workflow ran on that commit.
- npm's `alpha` tag still selected `0.1.0-alpha.19`; `latest` selected
  `0.1.0-alpha.1`. No `alpha.22` release run existed before the manual dispatch.
- The maintainer authorized starting
  [run 41534711436](https://github.com/jderochervlk/rescript-lint/actions/runs/41534711436)
  on verified `main` with `stage=true`. It subsequently built all five targets
  and staged all six packages. This is not evidence that npm publication approval
  occurred.
- `VERSION_AUTOMATION_ENABLED=true`. GitHub's `npm` environment requires
  approval by `jderochervlk`; this is separate from npm's publication review.

Intended outcome: after a registered version PR merges to `main`, automation
builds that exact merged commit and stages its five native packages and launcher
for npm review. No manual workflow dispatch, tag creation, or GitHub environment
approval should be needed for future automatic staging. Publication still
requires the maintainer's npm 2FA approval, native packages before the launcher.

## Scope and non-goals

- Keep the existing source-merge counting and version PR protocol. Several
  source merges may aggregate into one version PR and therefore one staged
  release. Do not stage every source commit with an unchanged package version.
- Stage each eligible merged version once, including catch-up after coalesced
  or suppressed events. Do not silently skip an intermediate merged version.
- Retain all five native builds, checks, license/source preparation, package
  coverage, rebuild tests, and installed-package smoke tests.
- Preserve manual build-only dispatch, explicit staging, and matching release
  tags, with the same duplicate-protection rule for every staging entry point.
- Do not automate npm approval, direct publication, `latest` changes, GitHub
  Releases, or tags. Do not add a registry token, OTP, PAT, or custom GitHub App.
- Fully unattended version-PR CI approval is separate work. This plan starts
  after the version PR has actually merged; it does not bypass existing checks.
- Automatic resumption of partially uploaded releases is out of scope.

## Approach and decisions

### 1. Reconcile releases from trusted main, not from one event

Keep `release.yml` as the top-level staging workflow and retain environment
`npm`, preserving the existing npm trusted-publisher identity. Do not call it
from `alpha-versions.yml` as a reusable publishing workflow: npm validates the
calling workflow's identity for reusable workflows.

Add pushes to `main` and an approximately 15-minute scheduled sweep throughout
the day to `release.yml`, alongside the current manual/tag entry points. A
restricted UTC-hour window was not specified or authorized, so the catch-up
schedule does not leave an arbitrary daily recovery gap. Main pushes and
scheduled sweeps need no enablement flag. Automatic jobs check the repository,
trusted main ref, and event allowlist before doing work, then validate the
reviewed cutoff and ledger. Ordinary PR CI remains read-only and never obtains
npm OIDC access.

Main pushes provide a fast path when delivered. Scheduled reconciliation is
required because `GITHUB_TOKEN`-originated merges can suppress push/PR events.
The selector must be lightweight; no candidate means no native/toolchain jobs.
Scheduled Actions are best effort, not a guaranteed 15-minute deadline.

Alternatives:

- Push-only or PR-closed-only triggers miss bot-originated merges.
- `workflow_run` after reconciliation precedes the version PR's eventual merge.
  After PR CI it can still race auto-merge or later reviews. It adds privileged
  PR-run handling without removing the need for scheduled recovery; defer this
  latency optimization.
- A new App/PAT would change authentication and operational ownership. Prefer
  scheduled reconciliation with the existing token for this scope.

### 2. Select an immutable, eligible release candidate

Use the existing main checkpoint and merged PR records as sources of truth.
Reuse the registered automation PR identity rules: recorded PR ID, expected bot
author, same-repository `automation/alpha-version` head, and `main` base.
Validate confirmed merge status, merge SHA ancestry in trusted main, checkpoint
consistency, and the canonical `0.1.0-alpha.N` version at that merge commit.
Titles, labels, an event SHA, or the bot author alone are insufficient.

Enumerate eligible merged version PRs after an explicitly reviewed rollout
cutoff. Select the oldest unresolved release, not merely the latest version
visible at the current main tip. Stop and report an uncertain earlier attempt
rather than silently dropping it or blocking it without an actionable summary.

Pass the selected source SHA and expected version explicitly through
`npm.yml`, every source/target-discovery checkout, and the staging checkout.
Validate those inputs against trusted selection; a user-supplied SHA alone is
not authorization. A later main push must not change the selected release.
Build-only diagnostic dispatches may still use other refs without staging.

Keep trusted control code pinned to the workflow's reviewed main revision in a
separate checkout from the selected release source. Do not replace selector or
ledger code by checking out an older candidate over it. Adapt staging to receive
the selected manifest, targets, and artifact paths explicitly rather than
implicitly importing the control checkout's package version. Manual and tag
staging must resolve the same canonical registered version-PR SHA; reject another
SHA claiming the same version.

Rebuild and verify the merged commit in this release run. Only consume this
run's verified artifacts, bound to the source SHA, version, target, package
names, and tarball digests. Do not download PR-run artifacts or stage a newer
source commit under the previous release version.

### 3. Persist staging attempts independently of Actions retention

npm's staged and public packages share the version uniqueness constraint.
The current OIDC staging credential cannot list, approve, or reject stages.
A public-registry 404 therefore does not establish that staging is safe.
Actions runs, artifacts, checks, and commit statuses also expire; they cannot
be the sole authoritative record of whether an old version was staged.

Use one data-only branch, `automation/alpha-staging-state`, as the release
attempt ledger. This adds one explicit state concept but avoids a new service,
credential, or code commit to `main`. Never execute code from this branch.
Reuse the repository's immutable Git-tree/commit and fresh-ref mutation patterns.
Create each ledger commit with the freshly read tip as its sole parent, then
update the ref with `force: false`. The API has no expected-old-SHA parameter:
a competing child makes the stale update non-fast-forward. Reread and replan;
do not merge a stale claim, force-push, or assume the failed response means the
write was rejected.

The ledger records its schema, reviewed rollout cutoff, and per-release:

- Version, registered version PR, exact merged source SHA, and original run.
- Original artifact references and verified package/tarball digests.
- An attempt marker persisted and confirmed **before the first npm upload**.
- Accepted package progress and stage IDs when available, without credentials.
- `Staged` only after all six uploads succeed; otherwise the known prefix and
  an inspection-required outcome.

Missing/corrupt/reset state, conflicting SHA/version ownership, ambiguous
mutation responses, or an unfinished upload attempt must stop automatic uploads.
Never interpret missing run history as permission to restage. A completed
ledger entry is a no-op with a link to its original run, not a new upload.
Before uploading, reread the ledger to confirm this run's exact attempt,
canonical source identity, complete package set, and tarball hashes were
committed. Do not reclaim incomplete attempts by age.

Serialize staging-enabled release runs across main, tags, and manual refs with
one stable concurrency group and `cancel-in-progress: false`. Re-read state
after acquiring the serialization boundary. GitHub can replace pending runs;
the next sweep must select from history and the ledger again, not an event
counter. Process at most one pending release per run; later sweeps drain backlog.

Only the trusted staging/ledger boundary gains `contents: write`. That token
permission is repository-wide, not branch-scoped; restricting writes to this
data branch is an application invariant, not a token capability. Keep protected
main and no-bypass policy, reviewed control code, and unpersisted checkout
credentials. Default, selection, and native-build permissions stay read-only;
grant `id-token: write` only where npm staging requires it. Define and verify
state-branch write/deletion protections before activation; do not bypass rules,
weaken protected main, or silently recreate a missing ledger.

If an upload times out, cancellation interrupts it, or recording an accepted
upload fails, stop for maintainer inspection. Initial automation is deliberately
one-shot, not automatic partial-release retry. Recovery must inspect npm stages
and use the original verified tarballs, not assume a rebuild is byte-identical.
Expired/missing artifacts or uncertain accepted uploads require explicit
recovery, potentially a new version. Do not claim uploads can be rolled back.

### 4. Remove the pre-staging approval, retain publication approval

For genuinely automatic staging, recommend removing required reviewers from
GitHub's `npm` environment while retaining that environment's name and suitable
ref restrictions. This requires explicit maintainer approval at rollout; this
plan does not authorize or perform the settings change.

Before doing so, verify all six npm trusted publishers are bound to this
repository, top-level `release.yml`, environment `npm`, and **stage-only**
permission. Verify that publication still requires maintainer npm 2FA and
disallows automation tokens. Do not remove the GitHub review gate while a
direct-publish permission could turn an OIDC staging credential into publication
authority. If the GitHub gate remains, label the result accurately as automatic
build/approval request, not automatic staging.

### 5. Make outcomes and recovery visible

Each run must summarize its selected version/PR/SHA, original artifact/run,
all six package outcomes, stage IDs when available, ledger state, and remaining
manual action. Distinguish `Skipped`, `Building`, `Staged awaiting npm review`,
and `Needs maintainer inspection`; green staging is not publication.

GitHub's workflow disable control pauses new automatic, tag, and manual release
runs. It does not cancel an active upload or approve/reject existing stages.
Document exact-run cancellation and inspection of an interrupted ledger entry;
never delete state or reset a checkpoint as a retry technique.

## Implementation steps

- [x] Commit this plan before implementation. The plan is committed; operational
  agreement/settings approval for the state branch and npm environment remains
  required before rollout.
- [x] Connect candidate selection and ledger transitions to injected
  GitHub/npm adapters. No live API was called.
- [x] Add operator-only ledger inspect/bootstrap commands and fail-closed
  read/update operations. No remote branch was created.
- [x] Add main/scheduled wakeups, shared serialization, immutable
  source/version propagation, and same-run artifact handling.
- [x] Wrap staging in the shared attempt protocol. Persist progress and
  actionable partial/unknown outcomes around
  [the existing staging boundary](../../scripts/npm/stage-release.mjs).
- [x] Complete adapter/integration regressions for mutation races, lost responses,
  artifact mismatch, source movement, suppressed wakeups, and unknown upload
  outcomes; all npm source-file coverage gates pass.
- [x] Add initial selector/ledger/orchestration/workflow regressions and update
  the release runbook, contributor guidance, and feature guide.
- [ ] Land through a separately authorized, reviewed change; coordinate cutoff
  and ledger setup with deployment and verify environment/branch restrictions.
- [ ] Audit the manual `alpha.22` run and existing public/pending packages.
  Set an explicit cutoff excluding that operator-owned release and earlier
  history; do not mark it staged merely because its workflow was dispatched.
- [ ] With explicit configuration/rollout authorization, initialize the ledger,
  approve the GitHub environment change, enable automatic staging, and record
  one controlled version merge plus a scheduled catch-up and repeated no-op.
  Leave npm publication approvals to the maintainer.

## Validation

Required regression cases:

- Wrong repository/ref/event, unmerged/wrong-base PRs,
  spoofed bot/head/title, missing registration, invalid version, and checkpoint
  drift produce no uploads.
- Human main push and a bot merge with no push delivery select the same exact
  eligible merge SHA; scheduled/manual catch-up finds every pending version.
  Raw source merges and ledger-branch writes cause no version/staging loop.
- Rapid/coalesced merges, later main movement, and pending-run replacement
  neither lose a version nor relabel its artifacts.
- Every native target and staging checkout uses the selected SHA. Foreign-run,
  missing, mismatched, or tampered package artifacts are rejected.
- Duplicate tag/manual/scheduled requests share the same lock and ledger.
  Lost GitHub responses, competing ref writes, missing ledger data, interrupted
  attempts, partial npm uploads, and failed final recording stop safely.
- A completed release stays a no-op after Actions history expires. Original
  artifacts are required for inspected recovery; new builds do not substitute.
- `stage=false` never uploads or records a staging attempt. No automated path
  approves stages, publishes directly, moves `latest`, or broadens PR permissions.

Local implementation validation commands:

```sh
node scripts/version/cli.mjs check
node --test test/version/*.test.mjs
node --test test/npm/alpha-staging-*.test.mjs test/npm/stage-release.test.mjs
node --test test/version/dune.integration.mjs
actionlint .github/workflows/*.yml
make check
opam exec -- dune build --profile release @install
npm run prepare:licenses
npm test
npm run test:rebuild
npm run pack:native
npm run test:package
git diff --check
```

Add focused tests for the new selection/ledger adapter beside the existing
version and npm staging tests. Hosted acceptance must prove all five targets,
OIDC stage-only permissions after the environment change, all six npm review
entries, delayed bot-merge catch-up, and a retry with zero additional uploads.
No local simulation alone establishes those GitHub/npm behaviors.

### Checks and operations performed for this plan

- Read live main, workflow/run metadata, npm public version metadata, existing
  release/version documentation, and the GitHub environment configuration.
- Dispatched only `alpha.22` run `41534711436` with `stage=true`; confirmed its
  source SHA is `5ba8b9ec63fb3dd71f1031e6f368747b438ff141`.
- The hosted run subsequently completed all five native jobs and staged all six
  packages for npm 2FA review. This is staging evidence only, not publication
  approval or evidence that any package was published.
- No remote settings change, state-branch creation, tag, GitHub environment
  approval, or npm publication approval performed.
- Passed `git diff --cached --check` for this plan and an ad-hoc Python check
  of its dates, required sections, balanced code fences, and five relative links.
- `git submodule update --init vendor/rescript` hydrated the local required
  submodule; the pinned gitlink is unchanged and no vendor changes were committed.
- Created a worktree-local OCaml 5.5 switch and installed the project dev
  dependencies; the switch is ignored and not part of the change.
- Passed `DUNE_ROOT="$PWD" make check`
  (build, format, OCaml lint, and Dune tests).
- Passed `node scripts/version/cli.mjs check` and
  `node --test test/version/*.test.mjs` (46 tests).
- Passed the focused alpha staging, artifact, CLI integration, workflow, and
  ledger command tests; the end-to-end fixture exercised accepted, duplicate,
  partial and unknown outcomes without live APIs.
- Passed `DUNE_ROOT="$PWD" npm run prepare:licenses`.
- Passed `DUNE_ROOT="$PWD" npm test` (99 tests; all npm source line, branch, and
  function coverage thresholds met).
- Passed `DUNE_ROOT="$PWD" npm run test:rebuild`,
  `DUNE_ROOT="$PWD" npm run pack:native`, and
  `DUNE_ROOT="$PWD" npm run test:package` on Linux x64.
- Parent independently verified the npm 11.15.0 JSON stage response contract
  with `--dry-run` against a loopback fake registry; the run sent GETs only and
  performed no real staging or API writes.
- Parent passed
  `OPAMSWITCH=/home/josh/Dev/rescript-linter DUNE_ROOT="$PWD" node --test test/version/dune.integration.mjs`
  (3 real-Dune metadata tests) using the existing switch without modifying it.
- Parent reran `node scripts/version/cli.mjs check`,
  `node --test test/version/*.test.mjs` (46 tests), and
  `node --test test/npm/alpha-staging-*.test.mjs test/npm/stage-release.test.mjs test/npm/release-preflight.test.mjs`
  (47 focused staging tests) on the integrated implementation; all passed.
- Parent verified the historical plan matches the original committed contents
  verbatim, checked document dates and 21 local links, and resolved an
  integration-only runbook conflict to the tested implementation's contents.
- Passed actionlint 1.7.12 on `.github/workflows/release.yml` and
  `.github/workflows/npm.yml`; the downloaded archive SHA-256 matched the
  published checksum.
- Passed `git diff --check`.
- Implementation and validation performed no remote GitHub/npm mutation,
  workflow dispatch, state bootstrap, tag, settings change, or npm approval.
  The earlier authorized manual `alpha.22` dispatch is recorded separately above.
- The feature guide preserves the original committed plan verbatim in its
  historical planning record. The active plan retains the unperformed rollout.

## Open questions and remaining work

The local selector, staging attempt protocol, artifact verification, workflow
entry points, and regression gates are connected and pass locally. Operational
rollout still requires a reviewed cutoff, maintainer agreement and protections
for the data-only state branch, stage-only publisher verification, explicit
ledger bootstrap, and a decision about the GitHub `npm` reviewer gate while
retaining npm publication 2FA. The local implementation is not deployed;
automatic reconciliation needs no enablement flag after deployment. The
15-minute scheduled path is best-effort reconciliation, not a hard deadline.

The manually requested `alpha.22` release completed all five builds and staged
all six packages. It must remain operator-owned and excluded by a reviewed
cutoff; do not replay or mark it staged in the new ledger.

References:

- [GitHub token event suppression](https://docs.github.com/en/actions/how-tos/writing-workflows/choosing-when-your-workflow-runs/triggering-a-workflow#triggering-a-workflow-from-a-workflow)
- [npm trusted publishing and reusable-workflow identity](https://docs.npmjs.com/trusted-publishers/#troubleshooting)
- [npm stage uniqueness and approval semantics](https://docs.npmjs.com/cli/v11/commands/npm-stage/)
- [GitHub retention applies to checks, runs, statuses, artifacts, and logs](https://docs.github.com/en/organizations/managing-organization-settings/configuring-the-retention-period-for-github-actions-artifacts-and-logs-in-your-organization)
