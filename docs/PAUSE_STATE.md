# Pause Checkpoint

Paused by explicit user request on **2026-09-21**. The user resumed work later
that day to prepare a Linux-only alpha release, including committing and pushing
this snapshot. This document remains the record of the pause; see
[`docs/RELEASING.md`](RELEASING.md) for the active release procedure.

## Committed and Pushed

Branch `main` is synchronized with `origin/main` at `eb5d800`.

- `2beb32d`: banned-API module aliases, opens/includes and project shadows;
  generated pinned runtime public scopes; opt-in ReScript 12.3.1 JSON throws
  contracts; tests and work logs.
- `eb5d800`: explicit dependency-package throws contracts, versioned JSON
  diagnostics, content-checked project parse reuse, discovery-aware watch mode,
  and configurable warning-comment terms/contexts.

Both batches passed their full checks, release builds, all 198 compiler-backed
catalog expectations, source/license bundle preparation, 43 npm tests, isolated
source rebuild/relink, native packing and installed Linux x64 CLI smoke tests.
No packages or release tags were published. The catalog remains 105 implemented
rule IDs; these batches improve existing rules and supporting infrastructure.

## Uncommitted Work

- **Per-file overrides:** strict `overrides` entries with config-relative literal
  `paths` and rule booleans. Ordered last-match settings, replacement/clear
  semantics, no globs or filesystem-existence requirement. Applied before linter
  prerequisites and during selected-file watch dependency decisions. Modules:
  `Rule_overrides`, `Rule_config`, configuration/linter/watch integration.
  71 focused tests. [Work log](WORK_FILE_OVERRIDES.md).
- **String comparisons:** `Literal_string` decodes JSON-compatible ordinary
  string escapes, validates UTF-8 and compares UTF-16 code-unit keys. Unsupported
  escapes/templates remain unknown. 52 helper cases and control-flow regressions.
  [Work log](WORK_LITERAL_SEMANTICS.md).
- **Named module-type throws contracts:** lexical templates/aliases and explicit
  constraints, public-signature authority and exception-reference remapping.
  Fresh exception templates still fail explicitly; no inferred functor results.
  51 focused tests including independent-review follow-ups.
  [Work log](WORK_THROWS_MODULE_TYPES.md).
- **Measured performance fixes:** independent JSX/React pack selection, tag
  guards around irrelevant descendant scans, and authoritative expression/policy
  inventories used to skip disabled families. Registry order is unchanged.
  [Work log](WORK_LSP_PERFORMANCE.md).
- **Benchmark harness:** `scripts/benchmark_lsp.ml` drives the real server through
  existing typed protocol/framing APIs. [Measurements](LSP_PERFORMANCE.md) record
  the 5,000-line JSX p95 improving from 7,999.852 ms to 145.336 ms, about 55x.
  Some large-file cases still exceed the provisional 50 ms target; this is not
  described as a completed responsiveness target.

README, throws contracts, logs and tests accompany the changes. None of this
batch has been committed or pushed. No new production dependency was added.

## Latest Verification

- Final `make check coverage` passed, including all 51 module-type cases and
  three additional review regressions. **95.55% (7403/7748)** overall; every file
  exceeds 90%. Literal helper and linter: 100%; overrides: 98.02%; throws
  traversal: 98.48%; throws scope: 99.07%.
- Latest report: `_coverage/run.3CHBof/html/index.html`.
- Release `@install` passed before the final test-only additions. Frozen release
  copy: `/tmp/rescript-module-types.E2ZNZ5/rescript-lint`, 18,484,752 bytes, SHA256
  `674cb885c154722e0d1b6b3287324acd5a86ca950bd22266c42283506f8b9535`.
- Real ReScript 12.3.1 fixture `/tmp/rescript-module-types.E2ZNZ5` compiled four
  modules. Imported named contract: unhandled call exits 1 with one JSON finding;
  matching exception catch exits 0. Escaped string equality produces the expected
  finding; an unsupported escape comparison remains unknown. The compiler emitted
  only the existing `raise` deprecation warning.
- Independent module-type review found no concrete defects. Its three suggested
  regression tests were added and passed in the final verification.
- After resuming, the full 198-example catalog audit passed with no skips on the
  `0.1.0-alpha.1` release binary. `npm run prepare:licenses`, `npm test`,
  `npm run test:rebuild`, `npm run pack:native`, and `npm run test:package` also
  passed after restoring the release build following coverage instrumentation.

## Grouped Issues Resolved

JSON format extraction could repair an earlier missing option value; regression
tests now retain the error. A cache timestamp test assumed unsupported floating
precision; it now compares actual stat metadata. A warning-comment range fixture
miscounted bytes; the exact expected end was corrected. Yojson does not update
`Lexing.lexeme_end` in its custom lexer; the string decoder now checks its actual
byte cursor, preserving strict full-input validation. Obsolete tests rejecting
all named types/constraints now check their supported public contract instead.
No coverage threshold or enabled-rule assertion was weakened.

## Historical Resume Order

1. Re-read Git status and this record; preserve any newer user changes.
2. Restore the release build after coverage instrumentation, then rerun the full
   catalog audit, `npm run prepare:licenses`, `npm test`, `npm run test:rebuild`,
   `npm run pack:native`, and `npm run test:package`. Root serializes Dune builds;
   do not change native sources during bundle/package validation.
3. Review and commit/push the batch when authorized to resume. The user
   subsequently requested that all local work, including
   `docs/PR_8351_REVIEW.md` and its link, be committed.
4. Reconcile `docs/PLAN.md` and older work-log next-step notes after verification.
5. Scheduling is **research only**, not implemented: initial inspection recommends
   latest-per-URI jobs, a server-generated revision token to prevent stale results
   across close/reopen, and one isolated analysis worker because parser thread
   safety is unproven. A worker alone cannot fix blocking partial-frame reads;
   cooperative transport needs design/testing using existing protocol facilities.
   No new scheduling module or transport change exists at pause.

Fresh exception-template instantiation, complete compiler type/effect inference,
live editor validation, upstream editor decisions and publication retain their
documented prerequisites. Do not confuse research recommendations or historical
plans with completed functionality.
