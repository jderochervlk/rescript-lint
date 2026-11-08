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
