# Per-File Rule Overrides Work Log

## Contract

Added bounded `overrides` configuration with explicit literal paths and rule
booleans. No generated-file guesses, automatic headers, wildcard rules, globs,
regexes, dependencies, or per-file project/adapter options are introduced.

```json
{
  "overrides": [
    {
      "paths": ["src/generated"],
      "rules": {
        "no-empty-file": false,
        "max-lines-per-function": false,
        "require-license-header": false
      }
    }
  ]
}
```

- Every selector is anchored to the defining config file's directory, regardless
  of project root or JSON key order. Absolute selectors remain absolute. Each
  config captures its decoding working directory for relative input filenames.
- Matching is lexical and does not read the filesystem or require files to
  exist. `.` and repeated separators normalize; source paths also normalize
  parent components. Symlink aliases do not match their targets implicitly.
- An exact selected path and descendants after a `/` boundary match. A selector
  for `src/generated` does not match `src/generated-old`. An explicit `.` selects
  the config directory and descendants; an explicit `/` selects the filesystem
  root and descendants. These do not imply disabling any unnamed rule.
- Selectors must be nonempty strings. Parent-traversal selectors, glob syntax,
  negation, backslashes, NUL bytes, and normalized duplicate selectors are
  rejected. Rules must be a nonempty object of known IDs and booleans. Empty
  selector arrays, missing required entry properties, unknown properties, duplicate
  properties/rule keys, and malformed values are rejected.
- The top-level overrides array may be empty: `[]` clears prior overrides.
  Supplying any array replaces the previous array; omitting `overrides`
  preserves it. Within the array, matching entries apply in order and the last
  explicit setting for a rule wins.
- Global rule settings, including later CLI flags, configure the base. Per-file
  overrides apply after that base. Options and adapters remain global, and
  enabling a rule through an override still requires its normal prerequisites.
- Overrides neither skip source parsing nor remove files from project semantic
  context. Discovery `exclude` remains a separate, broader operation. Suppression
  validation still uses the full global known-ID registry.

## Implementation

- Applied functional-code-style and writing-functions. The new `Rule_overrides`
  module validates structured JSON and resolves normalized selectors as immutable
  values. Working-directory acquisition is confined to configuration decoding,
  and its expected failure becomes an error value.
- Kept overrides inside `Rule_config`, avoiding a dependency cycle through
  `Project_options`. Added `with_overrides ~base` and `for_file ~filename`.
- Preserved base rule state independently of effective state. Resolving file B
  from file A's effective config starts from the original base, and resolving
  the same file repeatedly is idempotent. `set` modifies the base and resets
  effective selection; `with_options` preserves override data.
- Added only an overrides-specific branch to `Config_file`. Root owns the
  shared linter activation boundary, exact watch dependency gating, and test
  registration. Watch should test effective activation for selected lint files,
  not merely whether an override anywhere could enable a rule.
- Left user changes in `docs/RULE_CANDIDATES.md` and the untracked review file
  untouched. No production dependencies or concurrent Dune builds.

## Verification and Follow-Up

- Added dedicated selector, precedence, validation, immutable-base, adapter
  preservation, config replacement, lexical overlay, actual-linter, and known
  suppression-ID tests. Tests intentionally require root linter integration.
- Formatting and whitespace checks run locally. Root owns compilation, complete
  tests, coverage, CLI/LSP integration, and packaging verification.
- Generated policy exclusions are satisfied by explicit rule overrides once
  integrated. Automatic generated headers and per-file adapter/threshold
  configuration remain outside this bounded contract.
- Final root full checks and coverage passed, including all 71 dedicated
  override cases. Overall coverage was 95.55% (7,403/7,748); Rule_overrides
  reached 98.02%, Rule_config 97.30%, and configuration and linter each 100%.
- Root integrated effective rules before linter prerequisite checks and exact
  per-file watch dependency activation. Production is frozen for the release
  benchmark and packaging gates; this final update changes only the work log.
