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
