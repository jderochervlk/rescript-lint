# Verified dependency pins

Created: 2026-10-31
Last updated: 2026-10-31
Status: Implemented
Issue: https://github.com/jderochervlk/rescript-lint/issues/30 (shared CI follow-up)

## Purpose and supported behavior

Project dependency installation selects the exact Opam versions recorded in the
[reviewed source inventory](../../scripts/npm/dependencies.json), including
transitive packages. `dune-project` owns these constraints; generated Opam
metadata carries them to developer and CI installs.

This fixes the [PR #47 Linux ARM64 failure](https://github.com/jderochervlk/rescript-lint/actions/runs/41225512061/job/124617579974):
the resolver selected ocaml_intrinsics_kernel v0.17.3 while the reviewed archive
was v0.17.2. PR #46's Linux x64 log showed the identical mismatch. Both branches
need deterministic selection of the already-reviewed version, not an application
version bump or relaxed license/source verification.

## Design and boundaries

Exact constraints were added for base, ocaml_intrinsics_kernel, ppx_deriving,
sexplib0, and wtf8. These are existing dependencies at existing reviewed
versions, not new libraries or upgrades. The regression in
`test/npm/compliance.test.mjs` requires a matching exact installation constraint
for every inventoried Opam source.

Source preparation still rejects mismatched versions, revisions, pins, and
archive hashes. ReScript remains pinned by its Git submodule rather than an
Opam constraint. Build-only and development tools outside the source inventory
retain their existing declarations. Dependency upgrades require source/license
review, an updated inventory, coordinated installation constraints and regenerated
metadata; see [production dependencies](../development/DEPENDENCIES.md).

## Validation

On the PR #47 follow-up, using Node 24 and
`OPAMSWITCH=/home/josh/Dev/rescript-linter`, with `DUNE_ROOT="$PWD"` for local
builds:

- `node --test --test-name-pattern="audited Opam" test/npm/compliance.test.mjs`
  failed before the constraints were added and passed afterward.
- Dune generated Opam metadata in a clean temporary project using
  `opam exec -- dune build --root . rescript_linter.opam`; `cmp` confirmed
  the committed metadata exactly matches that output. In-tree generation copied
  the existing metadata rather than replacing it. The attempted
  `dune promote --root` was rejected because that alias does not accept the flag;
  no metadata was hand-designed to work around the generator.
- `opam install . --deps-only --with-test --with-dev-setup --dry-run --yes`
  reported nothing to do with the already-reviewed installed dependencies.
- `make check` passed build, formatting, lint (488 sources, zero findings),
  and tests.
- `opam exec -- dune build --root "$PWD" --profile release @install` and
  `npm run prepare:licenses` passed with source verification unchanged.
- `npm test` passed all 65 tests and 100% line, branch, and function coverage.
  An earlier run was interrupted; the complete rerun supplied these results.
- `npm run test:rebuild`, `npm run pack:native`, and `npm run test:package`
  passed source relinking and the local Linux x64 installed-package smoke test.
- `node scripts/version/cli.mjs check` and
  `node --test test/version/*.test.mjs test/version/dune.integration.mjs`
  passed consistency and all 15 version tests.
- `npm run audit:release -- 0.1.0-alpha.3` returned `PublicReleaseAvailable`
  after the maintainer published the missing Windows version. This is separate
  registry evidence, not an effect of the dependency constraints.

Validation reused the compatible switch without installing dependencies or
changing global configuration. An ignored local `_opam` link lets the existing
compliance CLI fixture select that switch. No package was uploaded. OCaml
coverage was not rerun because application code did not change. Local checks do
not prove fresh resolution on all five hosted runners; their CI remains required.

Before integrating PR #47's landed changes, the same correction was applied to
PR #46 and separately passed `make check`,
the release build, `npm run prepare:licenses`, `npm test` (59 tests, 100%
packaging coverage), `npm run test:rebuild`, `npm run pack:native`,
`npm run test:package`, and `node scripts/version/cli.mjs check`. The test
count differed because that branch did not yet include PR #47's public-audit tooling.

## Historical planning record

The original committed plan follows verbatim as historical intent:

```markdown
# Verified dependency pins

Created: 2026-10-31
Last updated: 2026-10-31
Status: Planned
Issue: https://github.com/jderochervlk/rescript-lint/issues/30 (CI follow-up)
Feature documentation: pending

## Problem and intended outcome

The Linux ARM64 job on PR #47 installed ocaml_intrinsics_kernel v0.17.3,
but the reviewed source inventory requires v0.17.2. License/source preparation
correctly rejected the mismatch. Installing project dependencies must select
the versions whose source archives and licenses the packaging gate verifies.

## Scope and non-goals

Constrain every inventoried Opam dependency to its existing reviewed version,
including transitive dependencies. Preserve archive hashes, environment checks,
compiler pins, package versions, and release permissions. Do not upgrade
dependencies or relax source verification. This is separate from the missing
public Windows package, which the maintainer has now published.

## Approach and decisions

Add the missing exact constraints to dune-project and regenerate Opam metadata
with Dune. Prefer deterministic dependency selection over accepting an unreviewed
new version or installing a one-off CI-only pin. Reuse the source inventory in a
regression test so future inventoried dependencies cannot remain unconstrained.

## Implementation steps

- [ ] Add a regression requiring exact generated Opam constraints for every
      inventoried Opam source and demonstrate the current failure.
- [ ] Pin the existing transitive versions and regenerate rescript_linter.opam.
- [ ] Document the installation/source-verification contract and this CI failure.
- [ ] Validate locally and update PR #47 without merging it. Check whether
      PR #46 has the same shared failure before applying the same correction.

## Validation

Run the focused regression, make check, npm run prepare:licenses, npm test,
npm run test:rebuild, npm run pack:native, and npm run test:package with the
existing compatible Opam switch. Run the public alpha.3 audit separately.
Inspect generated metadata and the final diff. Hosted all-platform CI is a
separate check; do not claim its results from local Linux x64 validation.

## Open questions and remaining work

The shared switch already contains the reviewed versions. Use it without
changing another checkout or installing dependencies globally. Verify dependency
resolution with an Opam dry run; hosted CI must still test fresh runners.
```

### 2026-10-31 delivery

Added all five missing exact constraints, regenerated and compared metadata,
demonstrated the regression before and after the fix, and passed the local
checks above. The PR #46 log confirmed the same source-preparation failure.
No version, dependency archive, verification gate, or release permission changed.
