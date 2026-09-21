# Throws Runtime Configuration Work Log

## Scope

- Added the explicit, opt-in `Rescript_12_3_1` throws runtime adapter to project
  options; the default remains `None`.
- Added strict JSON `throwsRuntime` decoding: the exact string
  `"rescript-12.3.1"` enables the adapter and `null` clears it. Unsupported
  versions, case variants, and nonstring values return configuration errors.
- Added `--throws-runtime rescript-12.3.1` to CLI parsing and help. Existing
  sequential configuration precedence and the `--` argument terminator remain
  unchanged. LSP receives the same configured rule options.
- Kept configuration separate from runtime rule behavior and preserved prior
  banned-API work. No dependencies were added.

## Verification

- Added focused configuration and CLI cases for the default, supported value,
  null, unsupported versions and types, missing values, a flag used as a value,
  option placement, argument terminator, both config/CLI override orders,
  independent adapter preservation, and LSP CLI/config propagation.
- Formatting and whitespace checks are performed locally. The root agent owns
  compilation, the test suite, and coverage; no concurrent Dune invocation is
  used for this batch.
- Initial root verification passed all 17 configuration cases and CLI behavior.
  That result was partial: an unrelated optional-label location parity failure
  still prevented an overall passing gate at that point.
- Final root verification passed `make check` and coverage, including all 17
  configuration cases, 49 integration cases, 6 CLI cases, and 76 upstream parity
  cases. Overall coverage was 95.40% (6,596/6,914); command, configuration, and
  linter coverage were each 100%.
- Production code is frozen for the root agent's release and packaging checks;
  this final update changes only the work log.

## Deferred Issues

- None identified in configuration. Runtime semantics are handled by the root
  agent's separate implementation batch.
