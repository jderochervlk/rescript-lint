# Empty project discovery

Created: 2026-10-22
Last updated: 2026-10-22
Status: Implemented
Issue: https://github.com/jderochervlk/rescript-lint/issues/34

## Purpose and supported behavior

Lint, fix, and watch distinguish a successful empty project selection from a
successful check of source files. Successful discovery returning no files emits
actionable guidance naming the selected root. Human output puts the warning on
stderr; JSON includes it in a `warnings` string array on stdout.

Empty discovery remains clean with exit code 0 for compatibility with legitimate
empty projects. There is no allow-empty flag because emptiness is not an error.
Nonempty successful runs remain quiet in human output.

All diagnostic JSON reports include `checkedFileCount`: the number of checks
returning successfully, including checks with findings, excluding read, parse,
analysis, write, and fix failures. It counts checks, not unique paths or edits.
Command and discovery failures count zero. Consumers can enforce nonempty runs
using this field. Watch emits a fresh count and warnings per run and continues
watching empty projects for source/configuration changes.

## Usage

At an aggregating workspace root, invoke each first-party project explicitly:

```sh
rescript-lint --project example-app --format json
rescript-lint --project packages/ui --format json
```

Run each in CI/task orchestration that preserves its exit status. One invocation
selects one project; repeated `--project` flags do not aggregate projects.
See the [README](../../README.md) and
[JSON contract](../diagnostics/JSON_DIAGNOSTICS.md).

## Design and boundaries

Discovery still selects only configured project sources after `exclude`.
Dependencies are not implicitly linted. Explicit file arguments still bypass
discovery; project metadata can still be loaded for analysis as before.
Zero-file warnings apply to empty `sources`, empty source directories, and
fully excluded sources, not to discovery failures. Warnings do not alter outcome
precedence, and schema version 1 gains only additive fields.

`Cli_runner` distinguishes empty discovery from failure at the report boundary.
`Report` counts successful results, and both reporters use that shared data.
Discovery and dependency traversal are unchanged.

## Validation

Added `empty_project_test` for human/JSON lint, fix, watch, exclusions, explicit
files, child selection, and empty-to-populated watch recovery.
Extended JSON reporter tests for successful-check counts and failed commands and
discovery. CLI integration compares an empty root with a child containing hook
violations; the existing watch integration now requires the empty warning.

Local evidence on 2026-10-22:

- Initial focused build, `make check`, and `make coverage` were blocked because
  the default Opam switch had no Dune. Network submodule cloning timed out.
- Recovered the exact pinned ReScript gitlink from an existing read-only local
  dependency checkout into this isolated workspace. No gitlink change.
- Used existing tools with `OPAMSWITCH=/home/josh/Dev/rescript-linter` and
  `DUNE_ROOT="$PWD"`; no external checkout or switch was modified by this task.
- `opam exec -- dune exec ./test/empty_project_test.exe`,
  `opam exec -- dune exec ./test/json_diagnostics_test.exe`, and
  `opam exec -- dune exec ./test/watch_test.exe` passed.
- A direct `dune exec` of `cli_runner_test` from the repository root failed its
  relative fixture reads; the standard Dune test alias supplies the correct
  working directory and passed it subsequently.
- `make check` passed after fixing formatting and replacing mutable test state
  with immutable before/after observations. Build, format, OCaml lint, unit,
  CLI, and watch integration checks passed.
- `make coverage` passed: 96.63% overall, all files at least 90%.
  `Report`, human reporter, and JSON reporter each reached 100%.
- OCaml parse-only checks for changed modules, `bash -n` on modified shell
  scripts, and `git diff --check` passed.
- npm packaging is unchanged; packaging checks are not applicable.

## Historical planning record

### Empty project discovery

Plan created: 2026-10-22
Plan last updated: 2026-10-22

The original pre-implementation plan follows verbatim:

```markdown
# Empty project discovery

Created: 2026-10-22
Last updated: 2026-10-22
Status: Planned
Issue: https://github.com/jderochervlk/rescript-lint/issues/34
Feature documentation: pending

## Problem and intended outcome

Aggregating workspace roots can select no files and silently appear clean.
Make that selection visible and expose a checked-file count.

## Scope and non-goals

Cover lint, fix, and watch reports and explicit workspace selection guidance.
Do not discover dependencies implicitly or add workspace configuration.

## Approach and decisions

Preserve exit status 0 for empty successful discovery for compatibility.
Add a human stderr warning and structured JSON warnings, preserving schema
version 1 with additive fields. Count successfully checked files, including
files with findings but excluding checks returning errors. Discovery and command
errors count zero. Empty explicit input without project discovery is unchanged.

## Implementation steps

- [ ] Add report count and empty-project warning across reporters and runner.
- [ ] Add focused CLI, JSON, and watch regressions.
- [ ] Document workspace selection and migrate this plan to feature documentation.

## Validation

Run focused CLI tests, then `make check` and `make coverage`. Verify counts for
clean, finding, and failed files and warning behavior across lint/fix/watch.
Record actual outcomes separately; do not commit missing submodule deletions.

## Open questions and remaining work

No unresolved product decisions. Dependency checkout and build tools may block
local validation; do not install global tools.
```

### 2026-10-22 delivery

Implemented all three planned steps without expanding discovery or adding
options. Kept compatible exit status and additive JSON version-1 fields.
Resolved local tooling and dependency blockers using existing read-only sources.
No product decisions remain open.

### 2026-10-22 review follow-up

Codex noted that the watch unit regression changed both sources and configuration,
so it did not isolate source-only recovery. Strengthened it to start with an empty
configured `src` directory and create a source file without rewriting configuration.
The watcher already rediscovers files on each snapshot; the existing live watch
integration also creates a file without touching configuration. No production
watcher change is needed.

The strengthened focused test, `make check`, and `make coverage` all passed
again with the same existing-switch environment. Coverage remained 96.63%.
