# Continued catalog implementation

Started 2026-09-20 23:47 America/New_York after the user clarified that the
first syntax wave was not the stopping point. The original work log is
[RULE_WORK_LOG.md](RULE_WORK_LOG.md).

## Objective and approach

Continue through all remaining 83 catalog candidates, including the shared
infrastructure their contracts require. Implement independent packs in parallel,
record initial failures and missing functionality, then resolve them in grouped
passes. A registered name without meaningful behavior does not count as a rule.
Compiler-delegated/rejected items in the research catalog are not candidates.

## Active ownership

- Semantic agent: 20 typed/API rules, immutable symbol/type context and runtime
  inventories. Log: RULE_WORK_SEMANTIC.md.
- JSX agent: 34 accessibility rules plus eight React DOM/JSX rules, shared JSX
  model and DOM/ARIA tables. Log: RULE_WORK_JSX.md.
- Test agent: all twelve test-framework rules using the actual installed
  rescript-vitest 3.0.1 source adapter. Log: RULE_WORK_TESTS.md.
- Main agent: project source discovery/index, five project rules, remaining four
  React rules, configuration/adapter activation, suppression, integration, and
  verification.

## Constraints and evidence

- Keep the earlier implementation and pre-existing dirty work intact.
- No production dependencies without asking; reuse OCaml, Yojson, Unix, and the
  vendored compiler libraries already linked.
- Build/test/coverage through the main agent only to avoid overlapping Dune runs.
- Adapter-specific rules require explicit configured adapter identity.
- Unknown semantic facts must stay unknown; do not substitute name spelling for
  symbol identity or claim full compiler-equivalent analysis.
- Prior compiler-audited examples and installed fixtures remain available in
  `/tmp/rescript-rule-compile-check` and related audit directories.
- Continue the functional-code-style and writing-functions skills; the JSX agent
  also applies react-component-style for React contracts.

## Progress

- Re-read remaining catalog, examples, current activation boundary, source and
  diagnostic modules, and available parser/runtime dependencies.
- Restarted all three independent agents on the remaining packs.
- Implemented and registered the remaining 83 rules: 105 total, with the existing
  twelve default rules unchanged. Optional rules remain explicitly activated.
- Added strict JSON config, explicit React DOM / rescript-vitest 3 adapters,
  project discovery from rescript.json, exclusions, entry modules, source overlays,
  public interfaces, source-inferred signatures, and configurable policy limits.
- Added compiler-artifact/report freshness validation for the actual Reanalyze
  JSON schema. Ran the pinned analyzer independently to inspect its output;
  declaration locations are taken from parsed source, not its unreliable multiline
  end columns. Unsaved sources and stale/missing artifacts return analysis errors.
- Added React render allocation, nested-component, context-provider and hook
  dependency analysis with lexical identity, stable setters/refs and field paths.
- The combined first implementation suite passed. Initial coverage was 91.66%
  overall but nine modules missed the per-file 90% gate; these are tracked and
  receiving focused behavioral/error-path tests rather than reduced thresholds.
- Audited 198 previously compiler-checked invalid/valid examples; the initial
  result was 167 expected outcomes. Grouped the misses into known-open identity
  bugs, fixture/configuration mismatches, and examples conflicting with conservative
  semantic contracts. No implementation is weakened to make an example pass.
- Threaded known project signatures into JSX and test adapters so known opens do
  not erase unrelated adapter identities; unknown/conflicting exports still do.
- Integrated audited ordinary-comment suppressions, including malformed/unknown,
  unmatched and unused-directive diagnostics. Parse/analysis failures cannot be
  suppressed. The suppression agent added 63 focused fixtures.
- Added deepEqualityThreshold configuration (minimum 2, default 4), explicit
  failure for empty restrictedModules policy, and hook custom-function/global
  scope regressions. A shared walker expression-copy issue was grouped and fixed
  at the scope snapshot boundary.
- Fixed a pre-existing watch CLI test startup race by silencing grep's expected
  missing-output-file error while polling. No watch semantics were weakened.
- Additional logs: RULE_WORK_SUPPRESSIONS.md and RULE_WORK_EXAMPLE_AUDIT.md.
- Expanded project/export/signature/report tests and fixed constructor/destructured
  public exports. Preserve opaque include/module signatures rather than dropping
  them and incorrectly treating an incomplete export list as complete.
- Added both modern `lib/ocaml` and legacy `lib/bs` artifact discovery after the
  real ReScript 12.3.1 build exposed the layout difference.
- Second full coverage run passed every module: 94.99% overall (6050/6369),
  report `_coverage/run.AzUKyT/html/index.html`. Main lint integration reached
  100%, project exports/signatures exceeded 96%, suppression exceeded 97%.
- Added CLI integration checks for relative project config/discovery, override
  order, missing-adapter analysis errors, suppression/fix behavior, unused
  suppressions and invalid JSON. The complete Dune suite passed afterward.
- Rebuilt every corrected catalog example with pinned ReScript 12.3.1,
  React bindings 0.15.0 and rescript-vitest 3.0.1. All 198 lint expectations
  passed, with zero skips, including a real unused-export report and live
  consumer. The reproducible audit snapshots its executable so simultaneous
  Dune builds cannot invalidate an in-progress run.
- Updated README, plan and rule references for 105 IDs. Added EXTENDED_RULES.md
  with activation, exact configuration, conservative analysis boundaries and
  suppression contracts. Remaining older throws/banned-API limitations are
  explicitly retained, not described as solved by the new infrastructure.
- Tightened policy/config validation: duplicate per-rule settings and flag-like
  missing CLI values fail; same-line comments after code are not license headers;
  malformed same-line analyzer ranges are rejected.
- Final review fixed known-signature alias ordering and opaque include quarantine,
  preserving private-module export masks and explicit external contracts. Added
  native input/list, named-image and dynamic landmark-role regressions.
- Fixed formatter stability validation to use the configured lint callback after
  parsing. Previously, an intentionally suppressed spacing gap could block fixing
  a different gap. Exact-output regression tests preserve both the suppression
  and the unsuppressed fix; existing formatter-conflict rejection remains tested.
- Added React memo/forwardRef render-body support with comparator/callback
  boundaries and four regressions.
- `make check` passed after these integration fixes. An exploratory `npm test`
  against the old compliance bundle failed nine packaging cases because the
  binary/source hashes changed, as the guard correctly requires. Regenerate the
  bundle from the settled release build before rerunning package verification;
  do not bypass the provenance guard or weaken packaging coverage.
- Refreshed compliance preparation succeeded; all 43 npm tests then passed with
  100% launcher/packaging statement-line, branch and function coverage. The
  release binary also passed the 198-example audit, SHA256
  `21f591d9838ed258a57fafe0a05628b6fc8919ea421e61563675d793b8173e2c`.
- Final coverage after module-resolution expansion reached 95.29% overall but
  walker coverage was 89.19%. Added targeted public-behavior tests instead of
  changing the gate. One newly added nested-module record-field test exposed a
  remaining inference/parser-shape issue; grouped follow-up is with the semantic
  owner while all other new tests remain green.
- The nested-record regression was a test-contract mismatch, not a production
  defect: no-float-equality intentionally exempts literal sentinel comparisons.
  The test now compares against a bound float, exercising export inference while
  preserving the documented exemption. Production code remained unchanged.

## Final verification

- `make check coverage`: passed. Coverage is **95.42% (6121/6415 execution
  points)**, with every implementation module at least 90%. The final walker
  coverage is 94.59%. HTML: `_coverage/run.as6e7U/html/index.html`.
- Release-profile `@install`: passed. Restoring the release profile after coverage
  reproduced the exact previously audited/prepared binary SHA256
  `21f591d9838ed258a57fafe0a05628b6fc8919ea421e61563675d793b8173e2c`.
- Compiler-backed audit: **198/198**, no skips or failures; ReScript 12.3.1,
  React bindings 0.15.0, rescript-vitest 3.0.1, and real Reanalyze JSON with
  189 analyzer findings. Report: `/tmp/rescript-rule-compile-check/catalog-audit.json`.
- Fresh compliance bundle and **43/43 npm tests** passed, with 100% measured
  launcher/packaging line, branch and function coverage. The earlier stale-bundle
  failures are resolved without weakening the provenance checks.
- `npm run test:rebuild`: passed. Bundled application/compiler sources rebuilt
  and relinked with a modified library, proving the expanded source archive is
  usable, not merely present.
- Updated the npm README's stale six-rule/no-configuration claims, then reran
  `npm run pack:native` and `npm run test:package`: passed. The packed Linux x64
  CLI works without OCaml tools on PATH. Local tarballs are under ignored `dist/`;
  this was packing/install testing only, not publication.
- Final release `--list-rules` inspection confirms 105 IDs, twelve defaults and
  93 opt-in rules. All agent work is complete and no required command is running.
- `git diff --check`: passed. No production dependencies, commits, pushes,
  release tags or publication were added/performed.

## Remaining boundaries, not unimplemented catalog IDs

All 99 candidate IDs now have bounded behavior, plus the six earlier rules.
See EXTENDED_RULES.md for the exact supported contracts. Advanced whole-program
typing/effects, package/workspace dependency discovery, computed browser
accessibility trees, arbitrary custom test/hook APIs, and the older project-wide
throws/banned-API resolution work are not claimed. Unknown facts remain unknown
or explicit analysis failures. Newly created source files require restarting
the initial-file-set watcher. Hosted non-Linux release verification and publishing
remain separate release tasks; nothing was published overnight.
