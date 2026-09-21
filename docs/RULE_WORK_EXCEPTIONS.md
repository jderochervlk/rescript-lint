# Exception and Debugger Rule Work Log

- Inspected candidate contracts, examples, parser representations, existing AST visitors, and exception handling analysis.
- Confirmed that the pinned compiler represents `%debugger` as an expression extension and provides `throw` and `raise` in `Pervasives`.
- Added `no-debugger`, `no-useless-catch`, and `no-catch-all-exception` in an independent rule module.
- Used lexical binding tracking for primitive rethrows. Unknown opens/includes conservatively disable primitive recognition because imported bindings may shadow it.
- Catch-all checks cover try handlers and exception patterns in switches; ordinary switch wildcards are unaffected.
- Attribute payloads are excluded from executable traversal. Diagnostics do not offer automatic fixes.

## Deferred Boundaries

- Imported aliases and opened-module exports require semantic resolution; the rule intentionally does not claim that these calls rethrow.
- Constructor reconstruction (`Not_found => throw(Not_found)`) and compound bodies are not treated as unchanged rethrows by this first syntax-only implementation.
- Generic suppression syntax is not established in the current repository; suppression remains the responsibility of future shared rule infrastructure.

## Verification

- Added focused parser-driven tests for all three rules, lexical shadowing, guards, aliases, nested handlers, module scopes, attribute payloads, interfaces, and exact byte ranges.
- First parent-run build found an OCaml record-label inference issue; adding explicit case types resolved it.
- First parent-run test pass found one unsupported local-open fixture (`Other.(...)`). Logged it and replaced it during the shared follow-up phase with the pinned parser's `{open Other; ...}` syntax. All other focused cases passed on the first run.
- The parent agent owns serialized build/test execution, coverage, and integration.
- Parent confirmed all 73 exception-rule cases pass after the fixture correction.

## Rule Selection Across CLI Modes

- Added a separate Bash-only `test/rule_modes_cli.sh` integration harness at the parent's request; it introduces no tool dependencies beyond the existing shell harness.
- LSP checks send framed initialize, unsaved didOpen, two didChange notifications, shutdown, and exit messages. The optional empty-function diagnostic appears, clears, and reappears with versions 1, 2, and 3.
- Watch checks cover both lint and fix modes, preserving the optional rule through a disk change. Source line movement distinguishes rerun diagnostics from initial diagnostics. Polling is bounded, changes are atomic, and an exit trap cleans up watcher processes and temporary files.
- First direct harness execution revealed fixture assumptions: outgoing LSP frames include a Content-Type header, and empty-function fixtures must use the explicit unit body `()` rather than `{}`. Updated the harness to reflect the existing transport and rule contracts.
- Bash syntax check and direct execution against `_build/default/bin/main.exe` passed all three LSP/watch scenarios.
- Parent's final review identified standalone structure/signature attributes bypassing the attributes-list visitor. Disabled the singular attribute callback too and added two parser regressions, bringing exception-rule checks to 75.

## Final coordinated verification

- All focused tests and CLI-mode regressions passed in the full suite.
- Exception module execution-point coverage: 98.72% (154/156).
- Release build passed. See RULE_WORK_LOG.md for the shared final report.
