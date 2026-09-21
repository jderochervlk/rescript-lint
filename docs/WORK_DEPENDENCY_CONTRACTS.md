# Dependency Contract Work

## Pinned Research

- `vendor/rescript/rewatch/src/config.rs:419` defines package-to-namespace spelling: retain ASCII letters/digits/underscore, capitalize after `/` and `-`, and discard other characters. `get_namespace` at line 486 distinguishes missing/false, true, string, and namespace-entry modes.
- `vendor/rescript/rewatch/src/build/namespaces.rs` describes compiler-generated namespace aliases and hidden internal `Module-Namespace` identities. Package files must not be exposed under guessed flat module names when namespacing is enabled.
- `vendor/rescript/rewatch/src/build/packages.rs:288` recursively reads declared package dependencies, excludes external-package dev dependencies, and diagnoses duplicate installed package identities. Namespace export generation at line 708 excludes exotic module spellings and handles namespace-entry specially.
- `vendor/rescript/rewatch/src/helpers.rs:158` implements package-relative, current-config, root and ancestor node_modules lookup, with separate workspace behavior. A home-grown basename lookup would not match this contract.
- Existing `Project_files` intentionally ignores node_modules, has no package namespace model, and does not interpret source `type: "dev"`. It must not be reused unchanged to discover dependency public declarations.

## Approved First Slice

- Explicit dependency root paths only, resolved relative to the lint configuration; require a configured project root. No implicit node_modules search, package installation, lockfile guessing, network access, or new production dependency.
- Read `rescript.json` only. Require a package name and an explicit supported source description; do not fall back to an older compiler configuration format.
- Support missing/false, true, and string namespace settings using pinned spelling rules. Reject namespace-entry rather than expose a guessed facade.
- Read normal source folders, skip dependency development-only sources, and reject unsupported source/configuration forms that can affect declaration visibility. Use `.resi` as the public contract when present; never copy implementation annotations across an interface as a generic rule.
- Every required non-development package dependency must appear in the explicit root list. Package indexing has an isolated local-module scope plus its declared dependency exports. Dependency cycles can fail with an actionable typed error in this bounded slice.
- Reject duplicate package identities, duplicate exposed module roots, and dependency/project root collisions. Runtime roots may be shadowed by explicit package/project declarations.
- Explicit dependency selection activates throws analysis for requested project sources. Disabling no-unhandled-throws skips dependency loading entirely. Known declarations without annotations have no declared contract, not a proof that they cannot throw.

## Implementation Shape

- New `Throws_packages.ml/.mli`: read/validate explicit roots, expose tracked input files, validate package graph, index isolated package declarations, and combine only their compiler-visible public roots.
- Add a small public `Throws_project.declarations` helper reusing existing fixed-point indexing and implementation/interface exception reconciliation. Keep the existing dependency-scoped caller activation unchanged.
- Root owns option/CLI decoding and Linter orchestration. Proposed scope API accepts current project module names so project/dependency collisions cannot silently shadow each other. Dependency file lists are available for subsequent indexing/watch integration.
- New focused tests cover namespace forms, local-vs-external module isolation, direct/transitive packages, interface precedence and identity aliases, source validation, dev-source exclusion, duplicate roots, missing dependencies, cycles, disabled bypass at the public boundary, and provider error provenance.

## Catalog Status

- All 99 accepted candidate IDs are implemented with bounded contracts, plus six earlier rules: 105 registered IDs, twelve defaults and 93 opt-in. `docs/RULE_OVERNIGHT_LOG.md` explicitly distinguishes remaining precision/infrastructure limits from missing catalog IDs.
- Since the overnight summary, configured-project throws, banned-API lexical resolution, and the pinned nine-contract JSON runtime adapter are also complete. Older "next" entries in HANDOFF and individual work logs are historical, not reopened tasks.
- Current planned infrastructure work is dependency-package exception contracts, JSON diagnostics, incremental project indexing and discovery-aware watch mode (`docs/PLAN.md`). Root/other agents own the latter three in this batch.
- Concrete remaining policy/precision items recorded in logs: configurable warning-comment terms/contexts; generated-file detection beyond configured path exclusions; full decoded-string constant comparison; compiler-backed type/effect information and additional module/type forms for throws. File overrides and automatic adapter discovery remain candidate infrastructure beyond the current explicit configuration contract.
- Advanced rendered accessibility trees, arbitrary custom test/hook APIs, indirect effects, and whole-program optimization proofs remain documented analysis boundaries, not missing rule implementations. The Oxlint ideas in RULE_CANDIDATES under "worth revisiting only with evidence" are explicitly unscheduled research, not authorized additional rules.

## Verification Log

- Initial work is read-only pinned-source research and this design log. Production implementation was subsequently authorized by the parent for Throws_packages and the narrowly shared Throws_project helper. Builds remain serialized by the parent.
- Implemented `Throws_package_config` for pure configuration decoding and `Throws_packages` for explicit filesystem loading, dependency ordering, isolated public scopes and watch input discovery. Added the shared declaration-index and exception-alias accessors without changing default throws activation.
- Added 80 focused tests, including ten public Linter cases. Coverage includes all supported namespace forms, direct/transitive graph ordering, interface precedence, hidden implementation metadata, precise callee ranges, dev sources, discovery without parsing, malformed configurations, symlinks, duplicate roots, disabled-rule IO bypass, project requirements and runtime coexistence.
- Grouped identity follow-up: reexported exception constructors can acquire a package-local interface identity. Preserve every package's equivalence pairs and canonicalize the combined graph before exposing the final scope, so declaration ordering and multiple reexports cannot separate the same exception. Tests also keep unrelated same-spelled exceptions distinct.
- Parent's full `make check coverage` passed: 95.47% overall (7206/7548), package configuration 92.44%, packages 95.85%, project throws 99.07%, throws scope 96.08%, and Linter 100%. Production/tests frozen during release verification; no pending changes.
- Parent independently compiled a three-module namespaced package fixture with actual ReScript 12.3.1 at `/tmp/rescript-dependency-contracts.It2ist`. `ThrowsLib.Api.run` without a handler produced one JSON finding and exit 1; a matching named catch produced exit 0.
- Final read-only review compared namespace normalization directly with pinned `namespace_from_package_name` and `get_namespace`. The supported ASCII namespace spellings agree; exotic/unusable module roots and namespace-entry are explicitly rejected rather than guessed. Package-global collisions fail before indexing, and cross-package exception maps are combined transitively before caller analysis.

## Follow-up Policy Contracts

- Warning comments: define configurable terms and comment contexts before changing the existing fixed TODO/FIXME/HACK policy. Tests should lock down default compatibility, case/word boundaries, empty replacement lists, ordinary versus documentation comments, and strings that merely resemble comments.
- Generated files: define exact recognized provenance markers and interaction with explicit include/exclude paths before adding detection. Test marker placement, unrelated comments containing generated-like words, unsaved buffers and watch updates; do not silently skip files from filename guesses.
- String constants: use parser/compiler decoding with explicit JavaScript string comparison semantics, not ad hoc escape replacement. Preserve the existing purity guards and test escaped quotes/backslashes, Unicode escapes and surrogate pairs, non-ASCII ordering, and equivalent literals with different spellings.
