# Shared source-unit construction

Created: 2026-10-22
Last updated: 2026-10-22
Status: Implemented; native lint validation blocked
Issue: https://github.com/jderochervlk/rescript-lint/issues/17

## Purpose and supported behavior

Project and dependency loading share `Project_files.construct_unit` and
`Project_files.duplicate_units`. Construction reads the selected source, parses
it and stats the original filename, in that order. It retains the supplied
source and tree, derives the module name from the filename, and records the
on-disk modification time. Reader/parser errors propagate unchanged; stat errors
retain their filename and `stat:` operation context as read errors.

Ambiguity means a repeated `(module name, source kind)` key. An implementation
and interface may share a module name; two implementations or two interfaces
may not. Each loader retains its original ambiguity diagnostic and ordering.

## Usage and design boundaries

These are internal library helpers, not new CLI or configuration features.
The project loader supplies its overlay-aware reader and parser (including
parsed-overlay precedence and content-validated parse reuse). Dependencies use
`Source.read` and `Parser.parse`, after validating module names.

Scanners remain separate. Project traversal skips symlinks and unsupported entry
kinds; dependency traversal rejects source symlinks and requires canonical,
contained source directories. Project excludes, root containment, configuration
formats, exotic dependency names, and boundary errors are unchanged. There is
no generic filesystem policy framework or new parser-injection option for
dependencies.

## Validation

On 2026-10-22, with the pinned submodule restored and the existing switch selected
read-only using `OPAMSWITCH=/home/josh/Dev/rescript-linter DUNE_ROOT="$PWD"`:

- `opam exec -- dune exec test/project_index_test.exe`: passed (54 checks).
- `opam exec -- dune exec test/project_errors_test.exe`: passed.
- `opam exec -- dune exec test/throws_packages_test.exe`: passed.
- `opam exec -- dune exec test/dependency_packages_test.exe`: passed.
- `opam exec -- dune runtest`: passed.
- `make check`: build/format and six adapter tests passed; native lint blocked by
  missing Zanuda in the existing switch. No dependencies were installed.
- `make coverage`: passed, 96.64% overall; Project_files 99.36% and
  Dependency_packages 95.78%; every file meets the 90% gate.
- `git diff --check`: passed.

Paired loader fixtures assert successful implementation/interface pairs, stable
order and modification times, parse errors, same-kind duplicate diagnostics, and
project-skip/dependency-reject symlink policies. Read/stat error sequencing is
tested directly at the shared construction boundary with disk and overlay
readers to avoid nondeterministic races or broadening loader interfaces.
The construction test keeps its linear scenario setup and assertions together
despite exceeding the usual function-size review target.

## Historical planning record

The original plan below is historical intent, not the current contract.
Plan created: 2026-10-22. Plan last updated: 2026-10-22.

### Original committed plan

# Shared source-unit construction

Created: 2026-10-22
Last updated: 2026-10-22
Status: Planned
Issue: https://github.com/jderochervlk/rescript-lint/issues/17
Feature documentation: pending

## Problem and intended outcome

Project and dependency loaders duplicate source reading, parsing, stat metadata
construction and ambiguity detection. Share these operations without changing
observable outcomes.

## Scope and non-goals

Share only construction and the `(module name, source kind)` duplicate predicate.
Keep discovery, ordering, overlays, parser caching, exotic-name validation,
containment, symlink policies and boundary diagnostics in their existing loaders.
Do not introduce a generic filesystem framework.

## Approach and decisions

Expose construction and duplicate detection through Project_files, which already
owns the unit type. Construction accepts explicit source-reader and parser
functions; it reads, parses, then stats the original filename. This avoids a new
module/type dependency cycle and keeps overlay selection outside construction.
Retain each scanner rather than parameterizing incompatible security policies.

## Implementation steps

- [ ] Extract construction and expose the duplicate predicate; use both loaders.
- [ ] Add paired implementation/interface, duplicate, metadata, read/stat failure
  regressions and explicit project-skip/dependency-reject symlink assertions.
- [ ] Run focused tests, make check and make coverage; record actual blockers.
- [ ] Promote this plan into feature documentation preserving this original text.
- [ ] Push branch, open PR linking issue, request GitHub Codex review and address
  available findings; return if review remains pending.

## Validation

Planned: `opam exec -- dune exec test/project_index_test.exe`,
`opam exec -- dune exec test/project_errors_test.exe`,
`opam exec -- dune exec test/throws_packages_test.exe`,
`opam exec -- dune exec test/dependency_packages_test.exe`, `make check`,
and `make coverage`. Verify deterministic unit order, allowed interface pairs,
same-kind rejection, source/parse/stat error ordering, metadata, overlay and
cache semantics, and differing symlink policies.

## Open questions and remaining work

The workspace starts with absent `vendor/rescript`; never commit its deletion.
Native tool availability and local dependency setup must be established without
global installations or editing outside the attached workspace.

## Progress and decisions — 2026-10-22

Construction and duplicate detection are shared through Project_files. Paired
loader regressions cover allowed pairs, same-kind ambiguity diagnostics,
deterministic ordering, stat metadata, parse failures and distinct symlink
policies. Deterministic read/stat failures are tested at the shared construction
boundary with disk and overlay readers, rather than adding parser injection to
the dependency loader or introducing timing-sensitive filesystem races.

Restored the pinned ReScript submodule inside this workspace. The default Opam
environment has no Dune. Using the existing switch read-only with
`OPAMSWITCH=/home/josh/Dev/rescript-linter DUNE_ROOT="$PWD"`:

- All four planned focused `opam exec -- dune exec test/<name>.exe` commands pass.
- `opam exec -- dune runtest` passes.
- `make check` passes build, format and six lint adapter tests, then fails because
  `zanuda:version` is unavailable: Zanuda is not installed in the switch. No
  package installation or external switch modification was attempted.
- `make coverage` passes: 96.64% overall; Project_files 99.36%,
  Dependency_packages 95.78%. Every implementation file clears the 90% gate.
- `git diff --check` passes.

The plan was promoted to this feature document on 2026-10-22. PR #38 was opened
and GitHub Codex review requested with `@codex review`. Review is pending; native
OCaml lint remains blocked. No merge or auto-merge is authorized by this work.
