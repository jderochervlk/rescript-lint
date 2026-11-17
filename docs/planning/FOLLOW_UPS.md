# Current State and Follow-up Work

This is the canonical backlog for work that remains after the implemented
milestones in [PLAN.md](PLAN.md). Completed milestones and dated release snapshots
are history, not active checklist items.

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
- Native npm packaging with source/license bundles and rebuild, pack, and
  installed-package verification. The dated target snapshot is below.

## Release Snapshot (2026-11-17)

The checkout at `2f105ecd` is `0.1.0-alpha.24` and contains 124 registered rules
(12 enabled by default). The npm registry reported `alpha` as
`0.1.0-alpha.22` and `latest` as `0.1.0-alpha.1`; these mutable tag values are a
snapshot, not a standing release guarantee. See the
[registry metadata](https://registry.npmjs.org/@jvlk%2Frescript-lint).

The stdio LSP server and separate [VS Code](https://github.com/jderochervlk/rescript-lint-vscode)
and [Zed](https://github.com/jderochervlk/rescript-lint-zed) integrations are
maintained in their own repositories. Editor integration development and
interoperability work belongs with those projects; it is not a missing client
implementation in this checkout.

The published package metadata lists five native targets: Linux glibc x64 and
ARM64, macOS x64 and ARM64, and Windows x64. This is the observed package target
set, not a promise of support beyond the published package's documented
compatibility limits.

## Remaining Analysis and Product Work

1. Add versioned LSP quick fixes for existing safe edits.
2. Add project-aware closed-file invalidation and multi-root editor behavior.
3. Extend throws analysis only with proven metadata: fresh exception-template
   instantiation, additional module/type forms and compatible compiler artifacts
   where source declarations are insufficient.
4. Consider semantic fixes for `no-optional-some` and
   `preferred-type-syntax` only after compiler-checked preservation tests cover
   comments, evaluation order and formatting stability.
5. Revisit alias avoidance and single-use-function only after resolving their
   policy conflicts and false-positive boundaries.
6. Treat additional platform/ABI support (including Alpine/musl, Windows ARM64,
   and older glibc) as separate release work with the portability and packaging
   gates listed in [NPM.md](../development/NPM.md).

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

For source or release changes, use the applicable checks below. They are
validation guidance, not claims that every gate is pending for this backlog:

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
