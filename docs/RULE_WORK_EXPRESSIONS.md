# Expression Rule Work Log

## 2026-09-20

- Read the candidate catalog, examples, existing control-flow implementation and tests,
  parser operator lowering, range conversion, and pinned runtime math interfaces.
- Applied the functional-code-style and writing-functions skills.
- Added `Expression_rules.check` using the existing AST iterator and diagnostic format.
- `simplify-boolean-expression`: direct boolean literal comparisons, neutral `&&`
  and `||` operands, `!!value`, opposite literal if branches, and exhaustive,
  unguarded two-case boolean switches with opposite literal results.
- `no-useless-concat`: two literal strings or an empty string operand in an
  actual `++` expression, including nested expression traversal.
- `approx-constant`: eight constants verified in
  `vendor/rescript/packages/@rescript/runtime/Stdlib_Math.resi`: `e`, `ln2`,
  `ln10`, `log2e`, `log10e`, `pi`, `sqrt1_2`, and `sqrt2`.
  Absolute tolerance is `0.000005`, including negative equivalents and exponent
  notation. Coarse approximations such as `3.14` deliberately remain accepted.
- All rules are diagnostic-only. Root integration owns disabled-by-default
  registration and configuration.

## Deferred Boundaries

- Do not simplify effectful `value && false` or `value || true`: replacing the
  expression by a literal would discard evaluation of `value`.
- No dynamic concatenation reassociation, template lowering diagnostics, wildcard
  boolean switch inference, or arbitrary boolean algebra. These require additional
  semantic reasoning or risk reporting expressions the author did not write.
- No fixes: preserving comments and resolving potentially shadowed `Math` requires
  further shared functionality and user review.

## Verification

- Initial focused expression-rule suite passed in the root's coordinated build.
- No concurrent dune process started here.

## Control-Flow Precision Follow-Up

- Audited the pre-existing, uncommitted control-flow module at the root's request.
- Duplicate switch guards now require the same normalized pattern; identical guard
  text on different matching arms is not sufficient evidence of duplication.
- Duplicate condition tracking resets after an intervening effectful expression.
  Switch guard tracking likewise resets at effectful or unguarded cases.
- Identical switch bodies now account for pattern bindings. Different patterns
  cannot share the diagnostic when either body refers to their bound names.
  Identical patterns and bodies independent of bindings remain supported.
- Added regression cases for each false positive and retained positive cases.
- Literal audit found that parser string contents retain escapes, OCaml UTF-8
  ordering differs from JavaScript UTF-16 ordering, and Int64 parsing accepted
  values beyond ReScript's signed 32-bit integer domain.
- At the root's request, addressed all three conservatively in the same batch:
  escaped strings are excluded from constant comparison, string ordering requires
  ASCII operands, and integer comparisons require both literals within signed
  32-bit bounds. Unescaped Unicode string equality remains supported.
- Added positive bounds/equality tests and negative escape, Unicode ordering, and
  out-of-range integer tests. Full decoded-string comparison remains deferred.
- Verified raw string escape retention in `res_scanner.ml`'s `scan_string` and
  signed integer handling in `compiler/frontend/bs_ast_invariant.ml` against the
  pinned compiler source, rather than assuming OCaml runtime semantics match JS.

## Final Precision Review

- Root reported expression module coverage of 100% after coordinated verification.
- Excluded standalone structure/signature attribute payloads explicitly via the
  iterator's singular `attribute` hook, alongside the existing `attributes` hook.
  Added implementation/interface regressions for both rule modules.
- Different switch patterns containing module unpack bindings are conservatively
  excluded from identical-body findings, because module members may resolve to
  different values even when their qualified expression text is identical.
  Identical unpack patterns retain support. Added negative and positive cases.

## Final coordinated verification

- Expression and control-flow regression suites passed in the full run.
- Expression module execution-point coverage: 100% (129/129).
- Control-flow module execution-point coverage: 97.61% (286/293).
- Release build passed. See RULE_WORK_LOG.md for the shared final report.
