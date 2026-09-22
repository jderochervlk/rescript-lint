# Configuration and Rule Expansion

Implemented 2026-09-21 following the next code milestones in `PLAN.md` and the
PR #8351 review. No production dependency was added and no release was published.

## Configuration

- `--inspect-config FILE` with human/JSON output, identical base/CLI/override
  precedence to lint, origin tracking, and explicit prerequisite status.
- Strict string-only `$schema` metadata, with no fetching.
- Generated npm `config.schema.json`, automatic registry/schema drift checks,
  runtime configuration fixtures, and independent JSON Schema validation.
- `maxLines` and `maxSwitchCases` options and structured `restrictions` entries.

## Shared Analysis and Reporting

- Scoped core-type traversal across implementations, interfaces, patterns,
  externals, payloads, module signatures and type constraints.
- Distinct standard and declared type identities, preserving aliases, opens,
  shadows and public `.resi` precedence.
- Exact value/type restrictions and module-prefix restrictions, with explicit
  exact/longest-prefix/first-tie precedence and legacy compatibility.
- Typed optional help/symbol metadata in human output, version-1 JSON and LSP
  messages/data. Existing diagnostics retain their original primary messages.

## New Rules

Eighteen opt-in IDs increase the catalog from 105 to 123. The twelve defaults
are unchanged. [POLICY_EXPANSION.md](POLICY_EXPANSION.md) defines each contract:
optional arguments, dictionary type spelling, integer identity/erasure/remainder,
FFI, record mutation, loops, branch style, static templates and size limits.

Each addition has valid/invalid compiler-checked examples plus focused tests.
Additional regressions cover shadows, unknown scopes, public type visibility,
module-type constraints, Unicode ranges, suppression integration, boundary
thresholds, config origins, overlap precedence, and cross-reporter metadata.

## Remaining Boundaries

Live Zed validation and publication remain release work. Declaration-origin
restrictions still require a provenance adapter; named module types and unknown
functor results are not promoted into resolved identities. Alias-avoidance and
single-use-function policies retain their documented design questions.

The new rules produce no edits. Semantic rewrites still require independent
compiler-checked preservation cases. Unknown source types are not replaced with
guessed facts, and existing parse, adapter, project and throws failures remain
errors.

## Verification

- `make check coverage` passed. Final OCaml execution-point coverage is
  **95.76% (8036/8392)**, with every implementation file above 90%. Report:
  `_coverage/run.vKI6kk/html/index.html`.
- New policy packs: syntax 98.29%, idioms 98.53%; configuration inspector 99.05%,
  restriction policy 90.38%, shared traversal 96.73%. Diagnostic rendering is 100%.
- Release `@install` build passed. All **234 compiler-backed catalog checks**
  passed with zero skips using ReScript 12.3.1, React 0.15.0 and Vitest bindings
  3.0.1. This includes 36 new invalid/valid checks.
- AJV independently compiled the shipped draft-2020-12 schema and accepted the
  complete valid fixture. Its all-errors validation rejected the invalid fixture's
  unknown fields/rules, malformed activation, adapter, paths, kinds and limit.
- `npm run prepare:licenses`, all **41 npm tests**, `npm run test:rebuild`,
  `npm run pack:native` and `npm run test:package` passed. npm coverage is 100%
  lines/functions and 99.35% branches; all per-file thresholds pass.
- The bundled sources rebuilt and relinked against a modified library. Installed
  Linux x64 smoke tests passed without OCaml tools on PATH, including shipped
  schema/registry agreement, effective configuration and typed policy metadata.
- `git diff --check` passed. No generated authentication state or credentials
  were introduced. Binaries and source bundles remain in ignored build outputs.
