# Incremental Project Parse Index Work Log

## Scope and Integration

- Reviewed project discovery/loading, semantic context construction, linter entry
  points, and CLI/watch/LSP adapters before designing the cache boundary.
- Added an immutable, explicitly owned `Project_index.t`. Each load returns the
  next cache, the normal project/error result, and per-load parse/reuse/overlay
  statistics. Root owns session lifetime and linter/client integration.
- `Project_files.load` accepts an optional explicit parser while retaining its
  existing discovery, disk-read, overlay, duplicate-module, and timestamp behavior.
- A cache fixes its parser at creation. No global mutable state; the compiler
  callback's mutable accumulator exists only inside one load invocation.

## Correctness Contract

- Discovery and disk reads run on every request. Reuse requires exact source
  contents, kind, and filename, so timestamp equality or same-length edits cannot
  preserve stale parses and source-location paths remain correct.
- Canonical root and normalized exclusions partition cache selection. Successful
  snapshots prune removed/excluded/config-unselected files. Configuration and
  filesystem changes are rediscovered rather than inferred from timestamps.
- Open-document overlays are authoritative but never replace disk cache entries.
  Identical overlays may reuse a disk parse; modified overlays are parsed without
  storing their result. Closing an overlay returns to freshly read disk contents.
- Disk read, parse, duplicate-name, and discovery failures return typed errors and
  clear cache entries. An overlay parse error preserves independent disk entries.
- This batch caches only syntax trees. Module signatures, dependency facts,
  semantic contexts, diagnostics, and freshness-dependent checks are recomputed.

## Verification

- Dedicated public API tests in progress; root serializes builds and integration.
- Added public tests for parser-call counts and immutable snapshots; same-length,
  same-timestamp edits; fresh timestamp metadata on reused trees; file/interface
  add/remove; root/exclusion/config-selection changes; and authoritative overlays.
- Added deterministic injected-parser races to remove a file between discovery
  and read, or between read and stat, verifying errors cannot reuse project
  success. Parse/config/duplicate-module errors and overlay error isolation are
  covered separately. No Dune command was run concurrently by this agent.
- Existing discovery semantics are preserved: an overlay outside discovered
  project sources is not inserted into the project snapshot by this cache.
- First coordinated suite found one test-only timestamp assertion mismatch:
  `Unix.utimes` rounds requested floating-point times to system precision.
  Corrected the metadata assertion to compare against the observed `Unix.stat`
  result, and normalized initial timestamps to an exactly representable integral
  value so same-timestamp source/config edit tests truly preserve the timestamp.
  No production changes were necessary.
- Final coordinated gates passed: 44 index checks, overall coverage 95.47%
  (7206/7548), `Project_index` 97.92%, `Project_files` 100%,
  `Project_context` 96.88%, `Linter` 100%, and CLI 94.74%.
