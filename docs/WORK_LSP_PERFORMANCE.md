# LSP Performance Work Log

## Evidence and Scope

- Parent measured the frozen `eb5d800` release through the actual LSP transport,
  using `scripts/benchmark_lsp.ml`: 5000-line p95 was 7999.852ms for the JSX
  fixture, 87.210ms for clean source, 151.018ms for hooks, and 63.364ms for throws.
  Baseline details and subsequent measurements belong in `LSP_PERFORMANCE.md`.
- The JSX fixture enables only `jsx-a11y/alt-text`, but the original linter
  adapter executed accessibility, React DOM, and semantic React packs whenever
  any rule from any of those packs was enabled.
- `React_semantic_rules.expressions` uses a linear physical-identity lookup for
  every expression in a later traversal. Its top-level visits also reconstruct
  all visible global identities. These are concrete quadratic paths that were
  unnecessarily executed for an accessibility-only request.
- `Jsx_rules.labels_checks` scanned all elements for nested controls for every
  tag, although the result is used only for labels. `media_checks` similarly
  filtered all elements for descendants before checking whether the tag was
  audio/video. A flat image fixture therefore incurred two avoidable quadratic
  scans even without enabled label/media rules.

## Bounded Changes

- Independently gate the three adapter packs by their existing authoritative
  rule inventories. Preserve prerequisite validation, pack order, and final
  stable diagnostic sorting. Every enabled rule continues to execute.
- Check label/audio/video tags before computing their descendant scans. Keep
  the same containment, unknown-child, spread, visibility, and naming behavior.
- Extract the existing three expression and six policy rule IDs into their
  owning modules, and consume those exact lists from `Rule_config`. Registry
  order/defaults remain unchanged. Skip each optional syntax pack only when
  every rule in that pack is disabled.
- Added public tests for independently enabled/mixed/disabled adapter packs,
  exact source/tie ordering, unchanged missing-adapter errors, nested versus
  sibling label/media relationships, registry parity, and optional-pack output.
  Existing per-rule enable/disable tests cover all nine optional syntax rules.
- No global cache, timing assertions, skipped enabled rules, new dependencies,
  or semantic-scope changes. Parent serializes builds and benchmarks.

## Deferred Profiling Candidates

- For explicitly enabled semantic React rules, replace expression list lookup
  with a per-check physical-identity index, preserving last-visit precedence and
  different AST nodes that share source locations. Keep original binding-node
  snapshots used when lint attributes produce copied expression records.
- Avoid rebuilding global identity sets for irrelevant top-level expressions;
  preserve aliases, shadowing, and function-boundary capture semantics. This
  requires separate behavioral tests, not a blanket scope cache.
- Visibility findings still search ancestor elements; control labels search
  labels; nested text flattening repeatedly concatenates strings. Profile those
  realistic enabled-rule workloads before introducing a shared JSX index.
- Semantic maps are persistent balanced maps. The flat declaration walker did
  not reveal the same obvious quadratic problem, so no speculative map rewrite
  was made. Type/export filtering and record-type lookup deserve dedicated
  type-heavy fixtures rather than conclusions from the image benchmark.

## Verification

- Coordinated `make check` and per-module coverage gate passed: overall 95.55%
  (7403/7748), `Linter` 100%, `Expression_rules` 100%, `Policy_rules` 97.59%, and
  `Jsx_rules` 91.83%. Registry, mixed-pack ordering, adapter prerequisites, and
  enabled label/media regression tests all pass.
- Production frozen for the optimized release benchmark and packaging checks.
