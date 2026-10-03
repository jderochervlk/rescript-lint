# Current State and Follow-up Work

This is the canonical backlog for work that remains after the implemented
milestones in [PLAN.md](PLAN.md). Keep it current when a task lands or a release
changes the boundary described below.

## Delivered

- In-process ReScript 12.3.1 parsing, byte-accurate diagnostics and deterministic
  CLI behavior.
- 124 registered rules: 12 enabled by default and 112 opt-in rules spanning
  syntax, bounded semantic analysis, React/DOM accessibility, tests and project
  policies.
- Project discovery, `.resi`-first public metadata, explicit adapters, audited
  suppressions and per-file rule overrides.
- Project, runtime and explicitly configured dependency contracts for bounded
  `@throws`/`@raises` enforcement.
- Effective-configuration inspection, a generated configuration schema,
  versioned JSON diagnostics and typed policy guidance.
- Source-derived declaration provenance and opt-in source-root restrictions for
  value/type references, including explicit dependency packages and failure on
  opaque required origins.
- Discovery-aware watch mode, content-checked project parse reuse, spacing fixes
  and a diagnostic language server over stdio.
- Linux glibc x64/ARM64 npm packaging with source/license bundles and rebuild,
  pack and installed-package verification.

## Current Release Boundary

The checkout is `0.1.0-alpha.2` and contains the 124-rule catalog. The npm
`alpha` and `latest` tags still point to published `0.1.0-alpha.1`, which has the
earlier 105-rule catalog. Live Zed interoperability and publication of the
current checkout are not complete.

The stdio LSP server and a separate Zed adapter are implemented. The adapter is
maintained in the `rescript-zed` repository rather than this checkout; its live
two-server acceptance matrix remains the next editor gate.

## Immediate Release Work

1. Merge the configuration and policy expansion after review.
2. Recreate the pinned compiler/adapter fixture and rerun the 236-example catalog
   audit against the release binary.
3. Run every gate in [RELEASING.md](RELEASING.md), including source-bundle
   rebuilding, native packing, installed-package smoke tests and both supported
   Linux CI targets.
4. Publish `0.1.0-alpha.2`, then remove the temporary version distinction from
   the root README after the npm tags resolve to the current release.

## Next Implementation Milestone

1. Complete the live Zed acceptance matrix with both language servers active.
   After it passes, publish the matching editor integration and submit or merge
   it into the intended Zed extension repository.
2. Rebenchmark the release after the configuration/policy expansion. The last
   recorded 5,000-line JSX change p95 is 145 ms against a provisional 50 ms
   target. Profile enabled semantic workloads before adding coalescing or
   background analysis.

## Later Planned Work

1. Add versioned LSP quick fixes for existing safe edits.
2. Add project-aware closed-file invalidation and multi-root editor behavior.
3. Build a thin VS Code client after the Zed and package contracts are stable.
4. Extend throws analysis only with proven metadata: fresh exception-template
   instantiation, additional module/type forms and compatible compiler artifacts
   where source declarations are insufficient.
5. Consider semantic fixes for `no-optional-some` and
   `preferred-type-syntax` only after compiler-checked preservation tests cover
   comments, evaluation order and formatting stability.
6. Revisit alias avoidance and single-use-function only after resolving their
   policy conflicts and false-positive boundaries.
7. Treat macOS, Windows, musl and older-glibc support as separate release
   projects with the portability and packaging gates listed in [NPM.md](NPM.md).

## Explicitly Deferred

The following are analysis boundaries, not active tasks:

- compiler-equivalent whole-program type and effect inference;
- computed browser accessibility trees;
- arbitrary custom framework, hook and test adapters;
- automatic generated-file detection;
- semantic rewrites without compiler-checked preservation contracts.
- whole-workspace unsaved-buffer provenance; the LSP currently overlays only the
  document being analyzed.

## Validation Gates

Run focused tests while iterating, then complete these gates before merge or
release:

```sh
make check coverage
opam exec -- dune build --profile release @install
npm run prepare:licenses
npm test
npm run test:rebuild
npm run pack:native
npm run test:package
git diff --check
```
