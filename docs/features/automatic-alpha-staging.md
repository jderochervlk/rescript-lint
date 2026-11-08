# Automatic alpha staging

Created: 2026-11-02
Last updated: 2026-11-08
Status: CI verified on all five platforms; deployment and operational rollout pending
Issue: https://github.com/jderochervlk/rescript-lint/issues/21
Plan: [Automatic alpha release staging](../plans/automatic-alpha-staging.md)

## Local implementation behavior

The [release workflow](../../.github/workflows/release.yml) defines the main-push
and approximately 15-minute scheduled reconciliation path. These events reconcile
automatically once the workflow is deployed; no enablement flag is required.
The selector uses trusted main, the registered alpha-version PR checkpoint,
canonical merge history, and a reviewed cutoff to choose the oldest pending
release. A no-candidate result skips native build jobs. Manual build-only
dispatch remains separate from staging, and tag/manual staging paths select
the same registered source identity.

The selector passes two inputs to [`npm.yml`](../../.github/workflows/npm.yml),
the reusable workflow that builds the native packages:

- `source-sha` is the exact merged commit selected for this release.
- `expected-version` is the package version that commit must declare.

Target discovery and every native build check out the same SHA, rather than
whatever `main` points to when each job starts. Each native build also checks
the package version against `expected-version`. If another version merges while
a release is running, its jobs still build the originally selected commit and
cannot silently package a different version. Staging downloads only artifacts
produced in that same workflow run and uploads the five native packages before
the launcher.

Trusted control code is pinned separately from release source, including the
hidden `.release-control` checkout used to produce artifact evidence. An older
pending release may predate the current verifier, so verification tooling comes
from the reviewed control revision without changing the source being built.
The leading dot keeps Dune from discovering and building a second copy of the
OCaml project. Each target's evidence binds its source SHA, run, version,
package set, and tarball digests. Archive manifests and launcher optional
dependencies are checked before OIDC or ledger claims; npm's stage response must
identify the expected package, version, digest, and stage ID. The run log and
GitHub step summary report the confirmed ledger state, original run, package
outcomes, and manual next action.

Archive reads pass a local filename to tar with the archive directory as the
working directory. This prevents GNU tar from interpreting a Windows drive
prefix as a remote archive host, without requiring GNU-only flags.

Staging attempts are persisted in the data-only
`automation/alpha-staging-state` branch. A run writes and rereads its immutable
attempt, records each accepted package in order, and marks completion only after
all six are accepted. Git commits have the observed ledger tip as sole parent;
branch updates use `force: false`. Completed duplicates are no-op outcomes.
Incomplete attempts, unknown upload results, missing/corrupt state, conflicting
identity, or ambiguous ref writes require maintainer inspection and cannot be
automatically retried. The ledger is not a substitute for npm stage inspection.

## Operational status and safeguards

This local implementation has not been deployed. It has not created a remote
ledger branch or changed repository/npm settings, GitHub environment review,
or npm publication 2FA approval. Once deployed, automatic reconciliation runs
without an opt-in; missing or invalid cutoff/ledger configuration fails before
native builds or uploads.
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

Use GitHub's [workflow disable/cancel controls](../development/RELEASING.md#pause-release-runs)
to pause runs; there is no custom enablement switch. Canceling an upload does
not make its ledger attempt safe to replay.

## Validation and recovery

See the [implementation plan](../plans/automatic-alpha-staging.md) for exact
local commands and remaining operational steps. The initial implementation
validation on 2026-11-03 passed:

- `make check` with the worktree-local OCaml switch and `DUNE_ROOT="$PWD"`.
- Version consistency and 46 version tests; 3 real-Dune metadata tests.
- 99 npm tests with every per-file and overall coverage gate intact.
- License preparation, source rebuild/relink, native packing, and installed CLI
  smoke tests on Linux x64.
- Checksum-verified actionlint 1.7.12 and Git whitespace checks.

The 2026-11-05 flag-removal revision passed 51 workflow/version tests, actionlint,
and documentation checks. Its `make check` is blocked by an incomplete local
ReScript submodule; normal initialization refused the existing nonempty target
directory. Full npm coverage and packaging/rebuild checks were not rerun for
this workflow-guard-only revision.

The first hosted PR run then exposed operator tests inheriting the runner's
Actions identity, plus Windows file-URL and CRLF assumptions. The repaired
fixtures explicitly distinguish local operator sessions from Actions; the
production bootstrap guard remains unchanged and its rejection test verifies
no state mutation. CLI paths use `fileURLToPath`, and workflow-expression
contracts run with LF and CRLF inputs.

The first repair passed 94 focused tests with `GITHUB_ACTIONS=true` and 100%
coverage for the operator CLI. Its hosted rerun passed both Linux and both
macOS targets. Windows then exposed tar interpreting a drive prefix as a remote
host and insufficient direct coverage of protocol-failure handling.

The follow-up uses local archive filenames and adds explicit failure-path tests.
Its 99 focused tests passed under Actions context; the artifact verifier reached
100% lines/functions and 96.49% branches, and the staging protocol reached 100%
for all three metrics. Full local native/npm gates remain blocked by the
submodule prerequisite, but the follow-up passed all five hosted targets in
[run 42104658068](https://github.com/jderochervlk/rescript-lint/actions/runs/42104658068)
at implementation commit `70f49aae1fcf1dbdb4790d36072f8554bf61cfe9`. This includes
native builds, full npm coverage, source rebuilds, package/install smoke checks,
and the Linux x64 repository/OCaml coverage gates.

These checks include actual CLI execution against fake APIs and an independent
real npm 11.15.0 dry run against a loopback registry. Passing PR CI does not
establish configured stage-only OIDC or a live automatic staging rollout.
Deployment and live staging acceptance still require separate authorization.

Review the ledger and all six `npm stage list` results after an interrupted or
ambiguous upload. Do not replay alpha.22 or any earlier operator-owned version.
Expired artifacts or an unknown accepted upload require explicit maintainer
recovery, potentially with a new version; uploads cannot be rolled back.

### Version-independent artifact fixtures (2026-11-08)

[Version PR #58](https://github.com/jderochervlk/rescript-lint/pull/58) exposed
a test-fixture regression on all five platforms in
[run 42508613581](https://github.com/jderochervlk/rescript-lint/actions/runs/42508613581).
The source fixture followed the repository version, while a negative check
assumed alpha.23 was different. At alpha.23, the identity check correctly
accepted the version and the test reached its incomplete archive stub instead.
A separate archived-version check had the same collision at alpha.21.
These were test defects, not reasons to relax artifact validation.

The fixture now accepts an explicit version and uses it consistently in source
metadata, archive names/manifests, dependencies, and target evidence. Negative
versions are selected from alpha.1 and alpha.2 so they always differ from the
selected version. The current repository version and counters 1, 2, 21, 22, 23,
and 24 exercise both identity boundaries. Requested-version mismatches must
fail before any external command runs. Production code and error assertions
are unchanged; no version, workflow, checkpoint, coverage threshold, remote
setting, ledger entry, or package publication is changed by this repair.

Local validation on Node 24.16.0:

- Reproduced the original failure against the exact PR snapshot
  `adef4fb6abe7e186b8ea9601ddb7b129e3024d5f`.
- Before the fix, the new matrix failed at both alpha.21 and alpha.23.
- The patched artifact test passed all 10 cases against that alpha.23 snapshot:
  `GIT_EDITOR=true node --test test/npm/alpha-staging-artifacts.test.mjs`.
- The combined staging/version suite passed 104 tests under Actions context.
  Artifact-verifier coverage passed the existing 90% gates: 100% lines,
  96.49% branches, and 100% functions.

  ```sh
  GIT_EDITOR=true GITHUB_ACTIONS=true node --test --experimental-test-coverage \
    --test-coverage-include="$(pwd)/scripts/npm/alpha-staging-artifacts.mjs" \
    --test-coverage-lines=90 --test-coverage-branches=90 \
    --test-coverage-functions=90 \
    test/npm/alpha-staging-*.test.mjs test/npm/stage-release.test.mjs \
    test/npm/release-preflight.test.mjs test/version/*.test.mjs
  ```

- An independent read-only review found no defects and passed all 10 artifact
  tests.
- `make check` stopped at `opam exec -- dune build @all @check @fmt` because
  Dune is unavailable. The ReScript submodule is also uninitialized.
- `GIT_EDITOR=true npm test` passed 91 of 110 tests. The other 19 require the
  missing native executable or installed Flow parser; full npm coverage
  consequently failed. This is not a full local release validation.

The repair belongs on a normal source branch, not the automation-owned version
branch. After it lands, version reconciliation can refresh the pending version
PR through its normal protocol. Hosted five-platform verification of the repair
is still required; the earlier hosted results above describe earlier revisions.

## Historical planning record

### Artifact fixture repair planned on 2026-11-08

The following plan was committed as `7144fbc` before implementation and is
preserved verbatim. Its checklist records original intent; the implemented
behavior and actual validation are described above.

````markdown
# Version-independent alpha artifact fixtures

Created: 2026-11-08
Last updated: 2026-11-08
Status: Planned
Issue: None; regression reported on [version PR #58](https://github.com/jderochervlk/rescript-lint/pull/58)
Feature documentation: [Automatic alpha staging](../features/automatic-alpha-staging.md)

## Problem and intended outcome

All five native jobs in [run 42508613581](https://github.com/jderochervlk/rescript-lint/actions/runs/42508613581)
fail the same artifact-evidence test. The fixture follows the repository's
version, but its negative identity check assumes `0.1.0-alpha.23` is different.
The version PR makes those values equal, so execution reaches archive decoding
instead of the intended early identity rejection. Another negative archive
check similarly assumes `0.1.0-alpha.21` is different.

Make version-mismatch fixtures remain mismatches across release bumps, without
changing production validation or broadening any expected error.

## Scope and non-goals

- Change artifact test fixtures and their regression coverage only.
- Preserve source identity, archive identity, digest, target, and dependency
  validation and the existing coverage thresholds.
- Leave the automation-owned version branch, package versions, checkpoints,
  workflows, ledger, repository settings, and npm publication unchanged.
- Do not replace a stale constant with the next release number.

## Approach and decisions

Allow the isolated source fixture to select its own version, consistently using
it in source metadata, native/launcher archives, and generated evidence.
Select a different valid alpha version by choosing between two fixed canonical
fixture versions; this guarantees inequality without coupling tests to the
release counter or parsing/incrementing it.

Exercise the current version and alpha counters 1, 2, 21, 22, 23, and 24.
Verify rejection of mismatched requested and archived versions, including
rejection before external commands for a requested-version mismatch.
Keep unrelated fixed versions in self-contained ledger/protocol scenarios.

## Implementation steps

- [ ] Commit this plan before changing tests.
- [ ] Add a fixture-version matrix and reproduce both stale mismatch constants.
- [ ] Replace the mismatch assumptions with guaranteed-different versions.
- [ ] Run focused artifact/staging/version tests and targeted coverage.
- [ ] Attempt the repository checks and record unavailable prerequisites.
- [ ] Consolidate this plan and validation into the staging feature document,
  preserving the original plan as a historical record.

## Validation

The exact PR failure was reproduced without changing the working copy by
extracting the relevant files from `adef4fb6abe7e186b8ea9601ddb7b129e3024d5f`
and running:

```sh
GIT_EDITOR=true node --test --test-name-pattern='^target evidence is produced only' test/npm/alpha-staging-artifacts.test.mjs
```

It failed with the same expected identity error versus actual archive-decoding
error seen on all five hosted platforms.

Planned checks:

```sh
GIT_EDITOR=true node --test test/npm/alpha-staging-artifacts.test.mjs
GIT_EDITOR=true GITHUB_ACTIONS=true node --test test/npm/alpha-staging-*.test.mjs test/npm/stage-release.test.mjs test/npm/release-preflight.test.mjs test/version/*.test.mjs
make check
npm test
git diff --check
```

Run artifact-verifier coverage with the existing 90% line/branch/function
thresholds. Validate the patched test against the alpha.23 snapshot as well as
the current checkout. Hosted five-platform CI remains the final platform check.

## Open questions and remaining work

The attached worktree has no initialized ReScript submodule or usable Dune
command. Full native/npm packaging checks may remain blocked locally; report
that separately from the focused tests. Publishing or merging a repair is not
authorized by this plan.
````

### Original plan committed on 2026-11-02

The following is the original plan from commit
`01d85b4834e5eb748dc82e3051280b6ca3f39be5`, preserved verbatim so squash merges
retain the intended scope and decisions. Its status, future-tense steps, and
then-current validation describe historical intent, not supported behavior.

````markdown
# Automatic alpha release staging

Created: 2026-11-02
Last updated: 2026-11-02
Status: Planned; implementation and configuration changes not started
Issue: https://github.com/jderochervlk/rescript-lint/issues/21
Feature documentation: Pending; extend the [alpha version guide](../features/alpha-version-automation.md) and [release guide](../development/RELEASING.md)

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
  on verified `main` with `stage=true`. That is a staging request, not evidence
  that all six packages have been uploaded or published.
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

Add pushes to `main` and an off-hour, approximately 15-minute scheduled sweep
to `release.yml`, alongside the current manual/tag entry points. Introduce
`ALPHA_STAGING_AUTOMATION_ENABLED`, defaulting to disabled. Automatic jobs must
check the repository, trusted main ref, event allowlist, and opt-in before doing
work. Ordinary PR CI remains read-only and never obtains npm OIDC access.

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

Disabling `ALPHA_STAGING_AUTOMATION_ENABLED` stops new automatic attempts, not
an active upload, explicit maintainer dispatch, or approval of existing stages.
Document exact-run cancellation and inspection of an interrupted ledger entry.
Never delete state or reset a checkpoint as a retry technique.

## Implementation steps

- [ ] Commit this plan before implementation; obtain agreement on scheduled
  catch-up, the data branch, and the environment-approval change.
- [ ] Add pure candidate selection and ledger transitions with explicit
  filesystem/GitHub/npm adapters. Reuse existing version/ownership guards.
- [ ] Add reviewed ledger bootstrap and fail-closed read/update operations;
  do not enable unattended bootstrap or rewrite existing version checkpoints.
- [ ] Add release opt-in, main/scheduled wakeups, global serialization, explicit
  source/version propagation, and same-run artifact binding. Preserve build-only
  dispatch and existing checks.
- [ ] Wrap every staging path with the shared attempt protocol. Persist progress
  and actionable partial/unknown outcomes around
  [the existing staging boundary](../../scripts/npm/stage-release.mjs).
- [ ] Add regression tests and update the alpha version feature guide,
  release runbook, contributor guidance, and workflow-contract assertions.
  Document delivered behavior and preserve this plan's dated historical record.
- [ ] Land through a separately authorized, reviewed change with automatic
  staging still disabled. Verify the settings and state-branch restrictions.
- [ ] Audit the manual `alpha.22` run and existing public/pending packages.
  Set an explicit cutoff excluding that operator-owned release and earlier
  history; do not mark it staged merely because its workflow was dispatched.
- [ ] With explicit configuration/rollout authorization, initialize the ledger,
  approve the GitHub environment change, enable automatic staging, and record
  one controlled version merge plus a scheduled catch-up and repeated no-op.
  Leave npm publication approvals to the maintainer.

## Validation

Required regression cases:

- Disabled/unset opt-in, wrong repository/ref/event, unmerged/wrong-base PRs,
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

Planned implementation checks, not results for this documentation task:

```sh
node scripts/version/cli.mjs check
node --test test/version/*.test.mjs
node --test test/npm/stage-release.test.mjs test/npm/release-preflight.test.mjs
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
- At the last status check, the hosted run was still building: Linux ARM64 had
  passed, the other four targets were in progress, and staging had not started.
- No workflow implementation, settings change, state-branch creation, tag,
  GitHub environment approval, or npm publication approval performed.
- Passed `git diff --cached --check` for this plan and an ad-hoc Python check
  of its dates, required sections, balanced code fences, and five relative links.
- Ran `make check`; it stopped at `opam exec -- dune build @all @check @fmt`
  with `[ERROR] Command not found 'dune'`. No toolchain installation or unrelated
  source repair was attempted for this documentation-only change.
- Did not run local version/npm suites, coverage, or packaging/rebuild checks;
  no implementation changed. The dispatched hosted release checks are separate
  from local plan validation and are not yet recorded as successful.

## Open questions and remaining work

Implementation is not started. Obtain maintainer agreement on the proposed
state branch and removing GitHub's pre-staging approval while retaining npm
publication 2FA. The scheduled fast/catch-up paths provide eventual staging,
not an immediate or hard-deadline guarantee. Any tighter latency requirement
should be decided before adding another event/authentication mechanism.

The manually requested `alpha.22` release remains separate operational work:
its builds and GitHub `npm` environment gate must complete before anything can
appear in npm's staged-package queue.

References:

- [GitHub token event suppression](https://docs.github.com/en/actions/how-tos/writing-workflows/choosing-when-your-workflow-runs/triggering-a-workflow#triggering-a-workflow-from-a-workflow)
- [npm trusted publishing and reusable-workflow identity](https://docs.npmjs.com/trusted-publishers/#troubleshooting)
- [npm stage uniqueness and approval semantics](https://docs.npmjs.com/cli/v11/commands/npm-stage/)
- [GitHub retention applies to checks, runs, statuses, artifacts, and logs](https://docs.github.com/en/organizations/managing-organization-settings/configuring-the-retention-period-for-github-actions-artifacts-and-logs-in-your-organization)
````

### Delivery decisions recorded on 2026-11-03

- The scheduled fallback runs every 15 minutes throughout the day; no
  hours-of-day window was approved. Event coalescing cannot advance the ledger
  past unresolved versions.
- Trusted control code and artifact evidence production are pinned separately
  from historical release source. Build-only diagnostics do not share the
  staging lock.
- Review added strict scalar/schema validation, order-independent canonical
  ownership checks, older-unresolved release enforcement for tag requests,
  pre-upload artifact verification, and actual CLI regression coverage.
- Local implementation and validation are complete. Landing, state bootstrap,
  protection/environment settings, activation, and hosted acceptance remain
  separately authorized operational work.

### Remove the enablement switch (2026-11-05)

Maintainer feedback removed `ALPHA_STAGING_AUTOMATION_ENABLED` from automatic
selection and concurrency classification. Trusted main pushes and scheduled
sweeps now use the staging lock without a repository-variable context. The
reviewed `ALPHA_STAGING_CUTOFF`, strict ledger checks, environment protections,
and npm publication approval are unchanged. GitHub's workflow controls replace
the custom switch for operational pauses.

This is a local implementation revision, not deployment or authorization for
remote setup. Its checks are recorded separately in the active plan; the
original committed plan above remains unchanged historical intent.

### Repair hosted test contexts and Windows portability (2026-11-05)

[Run 42060485236](https://github.com/jderochervlk/rescript-lint/actions/runs/42060485236)
failed in the npm test/coverage step on all five platforms. The fix changes
test subprocess context, native path conversion, and line-ending normalization;
it does not relax production authorization, skip a platform, or lower coverage.
The active plan records the CI-context reproduction, targeted coverage, local
native-check blocker, and remaining hosted verification.

### Keep Windows tar paths local and cover protocol failures (2026-11-05)

[Run 42069410269](https://github.com/jderochervlk/rescript-lint/actions/runs/42069410269)
confirmed the first repair on four targets. The remaining fix passes archive
filenames relative to tar's working directory in both the verifier and real
fixtures, updates test doubles to honor that directory, and checks actual
manifest mismatch errors. Direct tests cover missing stage IDs, digest drift,
progress/completion errors, and failed inspection updates without weakening the
staging protocol, authorization guards, or coverage thresholds.
The subsequent hosted run `42104658068` passed all five native targets.
