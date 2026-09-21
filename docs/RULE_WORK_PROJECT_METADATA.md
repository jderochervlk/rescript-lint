# Project Metadata Follow-Up Log

- Added `test/project_metadata_test.ml` and its Dune test stanza at the parent's request to exercise public export discovery and inferred signatures, initially measured at 40% and 34% coverage.
- Parser-driven tests cover primitive/container/function types, explicit annotations, FFI identities, deprecated attributes, destructuring, nested/recursive modules, interface precedence, constrained exports, and source locations.
- Found and fixed missing constructor/variant/or-pattern export names and missing inferred signatures for destructured bindings. The whole-pattern annotation is not reused incorrectly as every component's type.
- Known inline includes now expose their declared values. Opaque aliases, functor applications, and includes retain explicit module-type markers rather than silently disappearing from inferred interfaces and losing potential shadow exports.
- Unknown external includes remain unresolved markers; consumers must treat them conservatively. Parent owns semantic consumer integration and serialized verification.
- Corrected the exact declaration-location assertion after checking the parser contract: a binding location includes the `let` keyword, not only its identifier. The assertion now reports actual line/byte bounds on failure.
- Serialized full-suite verification passed. Coverage: Project_exports 96.61%, Project_signatures 96.20%.
