# Banned API Resolution Work Log

## Scope

- Committed the completed 105-rule expansion and project throws batch as
  `b53614f`, then pushed `main` to `origin`, including its two existing commits.
- Inspected Git configuration/worktrees; no locally tracked PR stack. Reviewed
  staged paths and scanned for common credential/private-key patterns before
  committing. No publication or dependency installation.
- Read the existing banned API rules, their runtime inventories and tests,
  semantic scope/walker and project metadata. Applied functional-code-style and
  writing-functions skills.
- Next batch: reuse lexical semantic traversal for module aliases, opens/includes
  and project-root shadows. Preserve capture-only value-alias reporting and
  canonical messages at the actual source reference range.
- Delegated public regression tests and runtime export-shape investigation to
  two agents. Main agent owns integration and serialized Dune verification.
- Review identified two up-front requirements: local value captures must not
  inherit reportable runtime provenance, and safe runtime names (for example
  `Js.Math.log`) must shadow earlier banned names correctly. Unknown opens and
  includes conservatively invalidate earlier unresolved bindings.
- Review found a shared-walker ordering bug: nested module exports re-resolved
  earlier includes against the final scope, so a later module shadow could
  change an earlier include's identity. Replaced final-scope reconstruction with
  forward export accumulation and added regressions in both directions.
- Inline signature constraints now recursively retain known identities only for
  explicitly exposed nested members. Captured source values clear reportable API
  provenance through a per-pass walker callback, leaving other rule callbacks
  unchanged. Project names shadow runtime roots before signature population.

## Verification

- Generated and formatted public runtime export shapes from pinned `.resi`-first
  parser input. Generator is development-only; deployed linting reads no runtime
  source files and adds no dependency.
- First full `dune runtest` passed the new alias/open cases but exposed two
  compatibility gaps: the old `Primitive_object.magic` spelling is hidden by its
  interface, and integrating findings later changed stable diagnostic tie order.
  Keep the explicit legacy spelling ban separately from public shape data and
  restore original tie ordering. No tests or coverage gates were weakened.
- Review also found inline constraints dropped declared attributes in the old
  walker. Merge public type/attributes with inferred identity, with deprecation
  regressions for direct and nested constrained exports.
- Grouped follow-up passed `make check coverage`: 55 new public resolution cases,
  two constrained-metadata regressions, 41 runtime checks including full generated
  snapshot parity, and all existing CLI/LSP/watch/rule tests.
- Coverage: **95.40% (6554/6870)**; every implementation module exceeds 90%.
  Banned API traversal is 100%, runtime scope 96.43%, shared semantic walker
  94.23%. Report: `_coverage/run.eLqCUn/html/index.html`.
- Both agents completed read-only final reviews without further concrete issues.
- A real three-module ReScript 12.3.1 fixture compiled at
  `/tmp/rescript-banned-api-compile.vqPgji`. The release CLI reports the three
  alias-resolved banned APIs and an opened console reference (exit 1); safe
  `Js.Math.log` shadowing and the earlier-include/later-shadow case pass (exit 0).
  Compiler warnings about deprecated math spelling/open shadows were expected;
  compilation succeeded.
- Release `@install` passed. The pinned compiler-backed catalog audit passed
  **198/198** examples, zero skips, including real Reanalyze output. Binary SHA256:
  `d6df91122aec28242b501857186607cf09955ce04a2802f77c62abd2b67ae6d8`.
- Updated README, npm README, rule contracts, plan and dependency-upgrade
  regeneration instructions. Runtime data is generated from public declaration
  names, not installed/parsed at lint runtime. The separate legacy cast-spelling
  compatibility ban remains explicit.
- Refreshed source/license bundle with `npm run prepare:licenses`; all **43 npm
  tests** passed at 100% measured line/branch/function packaging coverage.
- `npm run test:rebuild` passed with an isolated modified-library relink. Native
  packing and `npm run test:package` passed on Linux x64 without OCaml tools on
  PATH. The archive includes generated runtime data, so deployed builds do not
  require the development generator or its test helper library.
- Final `git diff --check` passed; release binary hash still matches the audited
  build. No required commands or agent work remain running. This completed new
  batch is uncommitted; `origin/main` contains the earlier `b53614f` push.

## Boundaries

Known declaration identities only: unknown opens/includes quarantine earlier
scope; named module constraints, functor results and dynamic contents are not
guessed. Configured project roots shadow builtins, but arbitrary cross-file value
alias bodies and custom FFI/raw JavaScript effects are not inferred. Existing
rule inventories and capture-only reporting remain unchanged. No new production
dependency was introduced.

Agent logs: [resolution tests](RULE_WORK_BANNED_API_TESTS.md) and
[runtime inventory](RULE_WORK_BANNED_RUNTIME.md).
