# JSON Diagnostics Work Log

## Scope and Schema

- Added opt-in `--format json`; `human` is the unchanged default. Repeated
  format options use the last supported value before a format/missing-value
  error or `--`.
  File paths after `--` are not inspected as options. Missing and unsupported
  format values return explicit command errors.
- JSON applies to lint, fix, and watch. Help, version, rule listing, and LSP with
  JSON selected are rejected explicitly rather than emitting non-JSON output.
- Every application pass emits exactly one compact JSON object on stdout. Watch
  therefore emits JSON Lines; the outer watch runtime may keep status banners
  on stderr. JSON application responses do not emit human errors on stderr.
- Schema version 1 has `schemaVersion: 1`, `outcome` (`clean`, `findings`, or
  `failed`), `exitCode` (0, 1, or 2), `diagnostics`, and `errors`.
- Every diagnostic has `rule`, `severity: "error"`, `message`, `filename`,
  `range: {start, end}`, `help`, and `fixes`. A position has one-based `line`
  and UTF-8-byte `column`, and zero-based `byteOffset`. End positions are
  exclusive. Each fix has zero-based inclusive `startByte`, exclusive
  `endByte`, and replacement `text`; fix order is preserved.
- `help` is currently `null`: the existing diagnostic model has no separate
  help metadata. No help text or documentation URL is fabricated.
- Errors have `kind`, nullable `filename`, `message`, and `diagnostics`.
  Kinds are `read`, `write`, `fix`, `unsupported-file`, `parse`, `analysis`, and
  `command`. Parse/analysis diagnostics live inside their error record, not
  duplicated in top-level lint findings. File and diagnostic order are stable.
- Fix mode reports the fix callback's remaining findings, preserving existing
  behavior. The schema does not claim edits were applied or provide a fix audit.
- Any error wins over findings for outcome/exit code, without dropping findings
  from other inputs. The existing exit code contract is unchanged.

## Implementation and Integration

- Applied functional-code-style and writing-functions; used existing Yojson
  serialization with no new dependencies or handwritten JSON escaping.
- Preserved `Command.t`, request/watch records, and `Command.parse`. Added
  `Command.format` and `parse_with_format` so rendering can retain an explicitly
  selected format even when another command argument is invalid.
- Added the pure `Json_reporter` module. Application collects typed per-file
  results and renders human or JSON output without re-running lint/fix callbacks.
- Root integration required: register `json_diagnostics_test` in `test/dune`,
  update the help snapshot, and run build/test/coverage gates. No edits to
  `bin/main.ml`, watch modules, shared documentation, or test registration were
  made by this subtask.

## Verification and Follow-Up

- Added focused tests for clean/findings/failed and mixed results; all six lint
  error constructors; parse/analysis payloads; byte ranges, fixes, escaping and
  Unicode; ordering; fix/watch dispatch; CLI errors, delimiters, option order,
  unsupported modes; explicit human parity; and project input failures.
- Root owns all Dune builds. Formatting and whitespace checks run locally;
  compilation, execution, and coverage results remain pending root verification.
- No functionality blockers identified in the first implementation. Watch
  refresh/source discovery remains owned by the root's parallel watch batch.
- Pre-build argument audit identified that extracting format options could
  otherwise let a later positional argument fill a preceding option's missing
  value. Extraction now preserves that error, with project and rule-option
  regression cases; malformed commands are not silently repaired.
- Final root `make check` and coverage passed. Overall coverage was 95.47%
  (7,206/7,548); JSON reporter and Application reached 100%, and Command reached
  98.39%. The root owns subsequent packaging and release verification.
