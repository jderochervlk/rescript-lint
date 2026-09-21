# Runtime Throws Adapter Work Log

## Scope

- Continued after the completed, still-uncommitted banned-API batch. No new
  commit, push, package installation or publication requested/performed.
- Inspected the throws index/traversal, immutable scope, runtime export snapshot,
  project options/configuration, CLI and pinned runtime declarations. Applied
  functional-code-style and writing-functions skills.
- The next plan item groups dependency/runtime contracts. This batch implements
  the pinned runtime adapter; package graph discovery remains a separate task.
- Found nine bare throws/raises annotations in `Stdlib_JSON.res`; the matching
  public `.resi` declarations omit them. A versioned opt-in adapter explicitly
  imports these verified contracts without changing project interface precedence.
- `--throws-runtime rescript-12.3.1` / `throwsRuntime` enables analysis for every
  selected file, including unannotated standalone sources. Default activation
  remains unchanged. Unknown qualified APIs and unsupported active effects still
  fail explicitly, rather than being inferred safe.
- Delegated configuration/CLI, integration tests and runtime inventory/parity to
  three agents. Main agent owns scope/index integration and serialized builds.

## Implementation

- Reuse the checked-in public runtime shape snapshot, not the banned-API scope's
  legacy compatibility additions. Annotated JSON paths require catch-all handling;
  other exported values carry no declared contract, not proof of no effects.
- Preserve explicit unknown module shapes. Project declarations overlay runtime
  roots, while `.resi` continues to define project public contracts.

## Verification

- First `make check` compiled successfully and passed the 49 runtime integration
  cases, six CLI checks and existing behavior regressions. Two verification
  issues remain for grouped correction: a help-text snapshot wording mismatch,
  and implementation/interface AST type parity for the runtime inventory.
- Updated the new help snapshot to the actual option description. Investigating
  parity at the declaration level before changing any normalization or contract;
  no gate or assertion is being relaxed to accept an unexplained difference.
- Per-declaration diagnostics narrowed parity differences to `parseOrThrow`,
  `parseExn` and `stringifyAny`. The pinned mapper preserves source locations in
  arrow argument labels; optional labels carry different `.res`/`.resi` spans.
  Normalize these locations while retaining labels, optionalness, FFI attributes
  and type structure, with negative tests for semantic differences.
- Compiled a real ReScript 12.3.1 fixture without warnings at
  `/tmp/rescript-runtime-throws-compile.IOL4Pq`. Adapter-mode unhandled calls exit
  1 at exact callees; catch-all handlers exit 0; a `JsExn(_)`-only handler exits 1
  because bare annotations require catch-all coverage. Without the adapter, the
  same unannotated unhandled fixture exits 0, preserving default activation.
- Grouped corrections passed `make check coverage`: all 49 integration cases,
  six new CLI checks, 17 configuration cases and **76** inventory/parity checks,
  plus all existing regressions. Detailed per-member type/annotation/FFI checks
  and seven positive/negative normalizer checks remain in place.
- Coverage: **95.40% (6596/6914)**, every implementation module above 90%.
  `Throws_runtime` is 96.15% (25/26), `Throws_scope` 96.04%,
  `No_unhandled_throws` 98.87%, and the project index, CLI configuration and
  linter integration are 100%. Report: `_coverage/run.CArGAl/html/index.html`.
- Final independent reviews found no additional concrete defect. Production
  files and tests are frozen pending release/package verification.
- Release `opam exec -- dune build -p rescript_linter --profile release @install`
  passed. The compiler-backed catalog audit passed **198/198**, zero skips,
  using pinned ReScript 12.3.1, React bindings 0.15.0, rescript-vitest 3.0.1 and
  real Reanalyze output with 189 findings. Release binary SHA256:
  `e7a36b0857fd897d0855a75172a1335b3e563fbdb3d8f42077e751081bfcde6c`.
- Regenerated source/license provenance with `npm run prepare:licenses`. All
  **43 npm tests** passed, with 100% measured launcher/packaging line, branch and
  function coverage. No stale-bundle guard was bypassed.
- Bundled source rebuild/relink, native package packing and installed Linux x64
  smoke tests passed. Installed execution required no OCaml tools on PATH.
- Final `git diff --check` passed, and the release hash remains identical to the
  audited build. No required command or delegated task remains running.
- This batch and the preceding banned-API work remain uncommitted; `origin/main`
  is still at the previously pushed `b53614f`. No new dependency, commit, push,
  release tag or publication was added/performed.

## Agent Logs

- [Runtime inventory and parity](RULE_WORK_THROWS_RUNTIME_INVENTORY.md).
- [Public behavior and CLI tests](RULE_WORK_THROWS_RUNTIME_TESTS.md).
- [Configuration and option parsing](RULE_WORK_THROWS_RUNTIME_CONFIG.md).
