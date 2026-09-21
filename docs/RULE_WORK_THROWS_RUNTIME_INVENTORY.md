# Runtime Throws Adapter Work Log

## Research and Contract

- Reviewed pinned implementation and interface declarations before changes.
  Exactly nine annotations occur in `Stdlib_JSON.res`; all are bare `@throws`
  or `@raises`, representing any exception, not a named exception subset.
- Verified the three parse APIs return `t`, four stringify-any APIs return
  `option<string>`, and two stringify-any filter APIs return `string`. All are
  direct synchronous `@val` external declarations. Reviver/replacer callback
  parameters do not imply promise results or returned functions.
- The `.resi` publicly exposes these names and types but omits annotations.
  This explicit versioned adapter promotes only these nine implementation
  contracts; it does not infer contracts from names, FFI primitives, or prose.
- Public adapted paths are `JSON`, `Stdlib.JSON`, and `Stdlib_JSON`. Legacy
  `Js.Json`/`Js_json` remains unannotated even where the JavaScript primitive is
  the same. Unannotated means no supplied contract, not proven nonthrowing.

## Implementation

- Added `Throws_runtime.scope` and `annotated_paths` from checked-in public
  export shapes. No runtime filesystem access or production dependencies.
- Opaque shapes remain unknown and their descendants are not materialized.
  Standard-library autoopens preserve builtin exception identities.
- Deliberately do not use `Banned_runtime.scope`: its implementation-only
  `Primitive_object.magic` compatibility seed must not bypass public masks here.
- Root owns the explicit opt-in configuration, activation, unknown-scope
  support, caller integration, and serialized builds.

## Verification

- Added inventory tests parsing every pinned implementation and interface for
  annotation drift, exact nine-member presence, normalized source/public type
  parity, synchronous return shape, FFI primitive identity, and public aliases.
- Added scope checks for every public row, all 27 adapted paths, known plain
  APIs, legacy isolation, opaque exclusions, and preserved builtin identities.
- Coordinated compilation and tests pending with root.
- First coordinated compilation and integration passed; the grouped normalized
  source/interface contract check failed. Added per-member contract, primitive,
  type, and synchronous-return details before changing normalization. Inspection
  found the compiler's default type mapper leaves arrow argument metadata
  unmapped. This was investigated before adjusting the equality check.
- Detailed rerun isolated `parseOrThrow`, `parseExn`, and `stringifyAny`: their
  optional argument labels contain source locations that the default mapper
  leaves intact. Added location-only normalization for labelled/optional labels
  and recursive argument attributes, preserving label spelling, optionalness,
  argument types, arity, and FFI payloads. Added negative regressions for each
  semantic distinction; no production contract changes were necessary.
- Final read-only review found no further adapter/parity issues. The public shape
  masks, legacy-module separation, opaque-node exclusions, and exact nine-contract
  promotion remain intact; type normalization removes locations only.
- Coordinated `make check` and coverage passed all 76 inventory checks. Runtime
  adapter coverage is 96.15% (25/26 points), throws scope 96.04%, throws analysis
  98.87%, and repository overall 95.40% (6596/6914 points). Root reports project,
  config, command, and linter integration modules at 100%. Production remains
  frozen while root completes release and packaging verification.
