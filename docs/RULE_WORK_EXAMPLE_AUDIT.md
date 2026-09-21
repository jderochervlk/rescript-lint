# Catalog Example Audit Work Log

## Starting evidence

- Initial lint audit reported 167/198 matching examples, but it assumed existing
  temporary fixtures and did not itself verify compilation or fixture fidelity.
- Reviewed the Markdown catalog, generated fixtures, compiler project, policy
  configuration, project rule prerequisites, and every initial mismatch.
- Applied functional-code-style and writing-functions to the JavaScript audit
  runner; reused existing compiler and adapter dependencies without installing
  or adding production dependencies.

## Grouped corrections

- Regenerate both halves from Markdown, preserving shared declarations while
  preventing Prelude imports from invalidating empty-file and license fixtures.
- Configure the exact documented policy thresholds and restricted-module policy.
- Create a real interface beside the valid require-interface example.
- Run the pinned compiler, then real Reanalyze output with a live consumer for
  the valid unused-export example. Never manufacture analyzer findings.
- Consulted the semantic-rule owner: payload-free option comparison is excluded,
  Array.getUnsafe belongs to no-unsafe, unknown external callbacks cannot prove
  purity, and arbitrary awaited effects cannot prove iteration independence.
- Updated those four examples to payload-bearing list pattern comparison,
  List.headOrThrow/List.head, pure arithmetic maps, and independent resolved
  Promise.resolve calls respectively.
- Moved exhaustive-dependency examples into actual components and listed both
  captured component props in the valid tuple dependency list.
- Found a real infrastructure mismatch: current ReScript writes artifacts to
  lib/ocaml, while freshness validation initially searched lib/bs only. Reported
  this to the root agent for a core fix rather than bypassing verification.

## Verification

- Added a checked-in typed scaffold at `scripts/rule-example-prelude.res` so the
  runner can regenerate fixture modules from the Markdown source itself.
- Compiler verification passed for all 198 independent halves with ReScript
  12.3.1, @rescript/react 0.15.0, and rescript-vitest 3.0.1.
- Real Reanalyze completed and produced 189 project diagnostics. Its report and
  fresh compiler artifacts were consumed directly by the unused-export rule.
- Initial lint execution overlapped the root's instrumented rebuild, which
  briefly removed the executable. These executions were correctly counted as
  failures. The runner now snapshots the executable and records its SHA256
  before compilation/audit so build-directory changes cannot race the audit.
- Stable-snapshot rerun: **198/198 passed, zero skips, zero failures**.
- Report: `/tmp/rescript-rule-compile-check/catalog-audit.json`.
- Verified binary SHA256:
  `4e20c47982e833613262d844946d760e8782f261e4db26ab107d528388ae395b`.
- `node --check scripts/audit-rule-examples.mjs` passed.
