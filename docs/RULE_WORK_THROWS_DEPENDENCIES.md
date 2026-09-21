# Throws Dependency Index Work Log

## Scope

- Read-only review identified identity, interface, activation, and diagnostic-source
  risks in extending throws analysis to project metadata; findings and adversarial
  cases were sent to the parent agent before implementation.
- Added a pure project-root dependency collector. It returns deterministic sorted,
  unique module names, using lexical local module scopes rather than text matching.
- Tracks qualified expressions, types, constructors, exception aliases, patterns,
  module aliases, opens, includes, and throws/raises attribute payloads.
- Local structures export only declared modules; opens affect lexical lookup without
  re-exporting ambient modules. Functor parameters, recursive module groups, and
  unpacked-module patterns shadow same-named project modules.
- Nonthrows attributes, including standalone attributes, are ignored. Referenced
  modules in function bodies still count because project activation needs them.
- No dependencies or shared semantic-module changes. Root owns serialized build,
  test, coverage, and integration verification.

## Verification

- Added parser-backed implementation/interface regression cases for dependency
  ordering, aliases, shadowing, scoped opens, type paths, and annotation payloads.
- Initial coordinated compilation and tests pending.
- Initial compilation passed; 52 cases passed and one local-open fixture used
  unsupported OCaml-style syntax. Corrected it to ReScript's block-local `open`.
- Added a separate module-type namespace so local signature constraints and
  functor parameter signatures retain nested module shadows without confusing
  module-type names with module names. Added implementation/interface regression
  cases plus qualified record and type-extension paths.
- Corrected two interface module-type fixtures to newline declaration separators.
  Lifted traversal helpers to top-level functions with an explicit reference sink;
  the only mutable accumulator now lives inside the public `modules` boundary.
  Pattern-bound module collection is a pure recursive transformation. Added
  nested tuple, array, variant, and exception-pattern traversal regressions.
- Imported project-open export shapes are not supplied by this API. References
  after such opens conservatively retain possible project-root dependencies;
  same-file opens/includes use known local export shapes precisely.
- Final coordinated check and coverage passed all 66 collector cases. Collector
  coverage is 93.39% (226/242 points), repository coverage 95.43%, with the
  unchanged per-module gate satisfied. Report: `_coverage/run.6v2fIH/html`.
  No further collector production changes; root owns final integration checks.
