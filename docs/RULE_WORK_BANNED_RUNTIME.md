# Banned Runtime Inventory Work Log

## Design

- Reviewed the existing banned API scanner and semantic walker before changes.
  Flagged capture-only value alias reporting, unknown-open shadowing, and delayed
  include export resolution as integration risks; root owns walker changes.
- Added a development-only parser-backed public export extractor and generator.
  Each runtime module's `.resi` takes precedence over `.res`. The extractor
  resolves module aliases/includes in bounded fixed-point passes and retains
  all public value names, including safe names that can shadow banned APIs.
- Unsupported module forms remain opaque. Source bodies are not evaluated;
  documentation attributes and embedded examples are not inspected as exports.
- Production `Banned_runtime.scope` uses only checked-in shape data, with no
  filesystem parsing or new production dependencies. API values are rebased to
  every public access path, including short standard-library auto-open names.
- Runtime inventory generation and tests will be executed serially by root.

## Verification

- Bootstrap data placeholder permits generator compilation before generated data
  exists. Root will replace it before running parity and API inventory tests.
- Root generated and formatted the public export snapshot successfully (10,251
  lines). First integration run passed all 55 new resolution tests; the existing
  `Primitive_object.magic` ban exposed a deliberate compatibility requirement:
  its implementation spelling was already banned even though its interface hides
  `magic`. Added this single documented compatibility seed outside generated
  public data, preserving honest parity and the existing rule contract.
- Added parity against freshly parsed pinned sources, direct/canonical API path
  checks, safe-open shadowing, hidden-interface exports, and synthetic export
  resolution regressions. Root owns serial build/test/coverage verification.
- Final read-only review confirmed standard-library auto-open values are rebased
  to short public paths without changing qualified runtime paths; interface masks
  remain authoritative; unresolved functors, constrained module types, and dynamic
  include shapes remain opaque rather than acquiring guessed API identities.
- Coordinated `make check` and coverage passed all 41 runtime checks and pinned
  source parity. Runtime scope coverage: 96.43%; banned API scanner: 100%; shared
  semantic walker: 94.23%; repository overall: 95.40% (6554/6870 points). Root also
  verified a real-compiler fixture. Production files remain frozen.
