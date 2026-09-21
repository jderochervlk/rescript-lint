# Semantic Rule Work Log

## Infrastructure

- Read all twenty typed/API catalog contracts and their examples, nearby scope
  implementations, the pinned AST definitions, and current runtime interfaces.
- Added a persistent semantic scope for local values, modules, aliases, opens,
  signature imports, explicit annotations, record mutability, and literal/API
  result inference. Unknown facts remain explicit `Unknown` values.
- Added a reusable scope-aware traversal with expression, binding-group,
  structure-item, and module-reference callbacks. Project analysis can inspect
  canonical imported paths and deprecation attributes through this scope.
- Added semantic rule diagnostics for all twenty catalog names, with conservative
  supported shapes and source ranges. No fixes or new dependencies are added.
- Missing essential facts generate `Analysis_errors` only for enabled candidate
  rules and concrete triggers, not for every unknown expression.

## Contracts and Boundaries

- Runtime symbols are resolved through known module scopes, aliases, and opens.
  Local/project modules shadow runtime roots. Interface metadata supplies imported
  value types and attributes. This is source-fact analysis, not full HM inference.
- Equality rules use known aggregate/float types. `@lint.identity` permits an
  intentional identity comparison, and `@lint.exactFloat` marks exact float code.
- Compound deep equality risk defaults to four; arrays/lists are conservatively
  unbounded. Primitive comparisons remain outside the expensive-equality rule.
- Pattern preference covers fixed nonempty list and payload-variant constructor
  patterns. The catalog example `user == None` conflicts with its explicit
  exemption for efficiently lowered payload-free comparisons; None stays exempt.
- Partial inventory covers the exported throwing List, Option, and Result APIs.
  The catalog Array.getUnsafe example belongs to the existing no-unsafe inventory,
  per the catalog's instruction to keep invalid-value APIs under no-unsafe.
- Async adapter exemption uses known returned promise types or an explicit
  `@lint.promiseAdapter` expression annotation. Independent loop awaits require
  a known Promise.resolve call or an explicit `@lint.independent` callee contract.
- Collection fusion requires proven pure callbacks. Accumulating-concat covers
  a resolved List/Array.reduce whose callback appends to its string accumulator.
- Recursive forwarding and group dependencies compare lexical binding identities.
  Standard-combinator detection supports the canonical pure List.map recursion.
- Eta reduction requires known matching positional arity, no wrapper attributes,
  no optional/labeled parameters, and no asynchronous wrapper.

## Verification

- Implementation awaiting coordinated root compilation and focused tests.
- No concurrent dune invocation is started from this agent.
- First coordinated suite compiled all semantic modules and passed most cases.
  Eleven failures share two causes: ReScript preserves pipes in the printable
  AST, so logical application normalization was missing; eta analysis also
  treated operator syntax as a directly aliasable named function. Recorded as a
  grouped parser/arity correction and addressed together before expanding tests.
- Full coordinated suite passed after the grouped correction. First coverage
  measured model 86.36%, rules 81.77%, walk 89.17%, and recursion 95.57%; added
  behavioral tests for the uncovered annotation, API, type, control-flow, and
  lexical-scope paths without changing coverage gates.
- Follow-up precision audit fixed eta suggestions for recursive wrappers and
  annotation-narrowed wrappers, recursion forwarding across changed labels,
  unreachably awaited while bodies, simultaneous binding scope, ambiguous record
  mutability, and initialization effects inside deferred local modules.
- Added explicit trusted `@lint.pure` callback and `@lint.independent` contracts;
  imported external APIs never acquire purity by name. Binding-level `@lint.*`
  annotations propagate to their expressions for adapter and equality exemptions.
- Audited the compiler-checked catalog examples. Their state fixture has one
  integer field (risk two, below the default four); their callbacks and loader
  are unannotated externals, so purity/iteration independence cannot be inferred.
  These are fixture prerequisite gaps, not a reason to guess semantic facts.
- Effect audit verified pinned `Primitive_int.div`/`mod_` can throw. Removed
  throwing integer operators and generic structural comparisons from automatic
  callback-purity proofs, because fusion can reorder exceptions. Promise
  construction/assimilation is not presumed pure; independent Promise.resolve
  awaits require a known primitive payload, preventing thenable side effects.
- Initialization analysis now detects known effects nested in arrays, records,
  tuples, constructors, call arguments, and reachable conditional expressions.
- The expanded suite passed and full coverage reached the required gate: model
  92.31%, rules 90.76%, walk 90.77%, recursion 95.73% (root run AzUKyT).
- Final module precision batch adds opaque-export quarantine, resolved signature
  includes/aliases, and bounded fixed-point import resolution, removing dependence
  on input module order. Cyclic unresolved aliases stay unknown. Local module
  signatures hide private members, and functor initialization remains deferred.
- External mutable reads are excluded from self-comparison proofs. Capturing an
  external value in a local binding creates a distinct stable snapshot identity.
- Await-in-loop excludes statically empty loops. Added metadata, stability, and
  module-boundary regressions; final gate rerun remains with the root.
- Root's final precision run passed all tests and the 198-example compiler audit;
  overall coverage was 95.29%, but newly added walker paths measured 89.19%.
  Added focused regressions for exported local record declarations, nested
  recursive-module exports, and opaque includes invalidating earlier value,
  module, primitive, and recursive-module exports. Production files remain frozen
  while root reruns the final verification gates.
- Corrected the new record-export regression's right operand to a bound float:
  literal sentinels are intentionally exempt from `no-float-equality`, so its
  original literal comparison did not exercise the rule's reporting contract.
- Final coordinated `make check` and coverage passed. Walker coverage reached
  94.59% (140/148 points); repository coverage reached 95.42% (6121/6415 points),
  with every module meeting the unchanged 90% gate. Report:
  `_coverage/run.as6e7U/html`. No production edits followed this verification;
  release-profile packaging smoke verification remains with the root.
