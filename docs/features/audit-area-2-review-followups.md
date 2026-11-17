# Audit area 2 review follow-ups

Created: 2026-11-17
Last updated: 2026-11-17
Status: Implemented in branch; [PR #63](https://github.com/jderochervlk/rescript-lint/pull/63) open, not merged
Issue: https://github.com/jderochervlk/rescript-lint/pull/5 and https://github.com/jderochervlk/rescript-lint/pull/22

## Purpose and supported behavior

This feature documents fixes and guidance produced by the audit of five
unresolved review threads on merged PRs #5 and #22.

Dependency signature inference now evaluates a package with its declared
namespace available during fixed-point inference. This lets a package's own
namespaced module references resolve to that package, preserving declaration
origins for consumer checks. Implementation includes are resolved against the
lexical scope at the include position, so a later module rebind does not change
the module whose members are exported.

The stacked-PR guidance now distinguishes local stack tracking from
remote-only membership, requires explicit noninteractive merge choices, and
does not claim a remote Stack exists for a one-PR submission.

## Usage

When determining whether a target PR belongs to a stack, a local `gh stack view
--json` exit code 2 is not proof that the target is unstacked. The documented
`gh stack checkout <branch-or-pr>` lookup can discover a remote-only stack, but
it fetches branches and establishes local tracking. Use it only when the
worktree is clean and the checkout is safe; otherwise stop and coordinate
instead of falling back to ordinary Git operations.

For an explicitly authorized agent-driven merge, specify the target, method,
and confirmation, for example:

```sh
gh stack merge 42 --merge-method squash --yes
```

After submitting a one-PR local stack, report the ordinary PR publication
without claiming that a remote Stack object was created. See the current
[GitHub CLI command reference](https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands)
and upstream [gh-stack issue #467](https://github.com/github/gh-stack/issues/467).

## Design and boundaries

`Project_signatures` now gathers per-item lexical scopes with
`Semantic_walk.structure_contexts`. Signature generation continues to use the
final scope where the existing inferred-signature behavior depends on the
completed structure. Include targets, normal module declarations, and their
inferred nested signatures now use the scope visible at the declaration.
Recursive module declarations retain their mutual-recursion group scope while
excluding later outer bindings. This prevents a later outer binding or module
shadow from changing an earlier module's type or provenance. Constrained module
expressions also derive their inferred origins from that lexical parent.

Package inference passes each package namespace into the existing
`project_signatures` fixed-point routine, while preserving its public signature
shape and filtering the origin map to namespace-qualified paths. This prevents a
namespaced package's unqualified local paths from colliding with declarations
exported by an unnamespaced dependency. Regression tests cover consumer
provenance, mixed namespaced/unnamespaced packages, later module shadowing, and
outer-scope changes after nested module declarations.

The official checkout lookup is not read-only. If it cannot be run without
disrupting existing work, this guidance deliberately stops rather than
pretending the branch is unstacked. The one-PR behavior is an upstream CLI
limitation/bug, not a guarantee that all future `gh-stack` releases will behave
the same; verify current command documentation and the resulting PR/stack state.

The five old GitHub review threads remain unresolved until the follow-up is
merged and the fix is confirmed on the relevant target. The follow-up PR must be
linked from those threads; [PR #63](https://github.com/jderochervlk/rescript-lint/pull/63)
does not claim the changes have landed.

## Validation

The original worktree had a pre-existing missing `vendor/rescript` submodule
checkout. It was left untouched. To execute project checks without restoring
that tracked path, a scratch snapshot was made from the worktree, with the exact
gitlink commit `679406560d169f1124653ab50795d5077570f078` checked out only in
that scratch snapshot.

On that scratch snapshot, the following passed:

- `dune exec ./test/project_metadata_test.exe`
- `dune exec ./test/project_dependency_edges_test.exe`
- `dune exec ./test/project_preparation_test.exe`
- `dune exec ./test/project_errors_test.exe`
- `dune exec ./test/dependency_packages_test.exe`
- `make check`
- `make coverage` (overall coverage 96.61%, 8999/9315 points)

Before applying the fixes, the newly added regressions failed against the
current-main implementation: the include test reported that the target resolved
as `Public`, and the dependency-edge test reported
`package namespace self-reference provenance`. This confirms both findings
reproduced rather than relying only on the review descriptions.

Independent review of the first PR63 head then found two regressions introduced
by that patch. New differential tests failed on that head and pass with the
corrective changes: nested aliases had their type/origin changed from
`int`/`Secret.resi` to `string`/`Public.resi`, and an unnamespaced package's
`Bridge.alias` could inherit an unrelated namespaced package's origin. The tests
include constrained normal and recursive modules, recursive aliases, and the
unnamespaced package's `.resi` interface case. A separate end-to-end lint
regression verifies that a recursive constrained alias through a later outer
module rebinding still reports the forbidden declaration.

`make check` initially exposed that the exact mutation-exception locations in
`.ocaml-lint-exceptions.json` became stale after the package inference edit
shifted the existing `edge_callbacks` source lines. The entries were updated to
the same three reviewed mutation sites; the final scratch `make check` passed
with 491 OCaml sources and zero new lint findings. Packaging checks were not
run because no packaging files changed.

## Historical planning record

### Audit area 2 review follow-ups

Plan created: 2026-11-17
Plan last updated: 2026-11-17

#### Original committed plan

# Audit area 2 review follow-ups

Created: 2026-11-17
Last updated: 2026-11-17
Status: In progress
Issue: https://github.com/jderochervlk/rescript-lint/pull/5 and https://github.com/jderochervlk/rescript-lint/pull/22
Feature documentation: pending

##### Problem and intended outcome

Five unresolved review threads on merged PRs #5 and #22 identify two possible
provenance defects and three gaps in the stacked-PR agent guidance. Confirm each
against the current source and current GitHub documentation, add focused
regressions and fixes for confirmed defects, and correct the guidance without
claiming merged fixes before a follow-up is merged.

##### Scope and non-goals

Included: dependency signature inference and include provenance in the source
tree analysis; guidance for discovering remote-only stack membership,
noninteractive stack merges, and one-PR submissions; focused tests and living
feature documentation.

Excluded: unrelated review findings, release/backlog/editor documentation,
other contributors' provenance work, resolving the old GitHub review threads,
and landing the follow-up PR.

##### Approach and decisions

Treat each thread independently. Preserve the package's declaration provenance
when its namespace resolves self-references; resolve includes from the lexical
scope available at their declaration rather than a later final scope. Keep the
stack guidance grounded in the current GitHub CLI reference and distinguish
remote stack membership from local tracking state. Because checkout of a
remote-only stack can establish local state, do not present it as a
side-effect-free query; when a safe remote-only lookup is unavailable, stop
before ordinary Git fallback and ask for a clean, coordinated checkout or
explicit confirmation.

Use one ordinary follow-up PR because the code, tests, and operational guidance
are independent deliverables that do not depend on one another. Do not resolve
the five existing threads; link the follow-up and describe its unmerged state.

##### Implementation steps

- [ ] Reproduce or disprove both provenance findings with current-code tests.
- [ ] Correct each confirmed provenance defect and verify with focused tests.
- [ ] Correct all three actionable stacked-PR guidance gaps using current docs.
- [ ] Document supported behavior and preserve this committed plan as its
      historical planning record.
- [ ] Run focused checks, `make check`, and coverage where relevant; open one
      focused PR without merging it.

##### Validation

Acceptance requires regressions demonstrating the package self-namespace and
lexical include-scope behavior, guidance that matches the current GitHub CLI
reference, successful `make check`, and a coverage run if source changes require
it. Record exact commands and results as performed. The local toolchain was not
yet available at planning time; investigate the repository-local Opam switch
before concluding checks are blocked.

##### Open questions and remaining work

Determine whether project-local Opam dependencies are available. Confirm exact
source/test harness behavior before implementing either provenance change.
Investigate the current GitHub reference's merge and one-PR submission contracts
and use its documented branch-name checkout behavior to safely address
remote-only membership.

#### Dated decisions and scope changes

- 2026-11-17: Verified both provenance findings by running the added tests
  against the pre-fix current-main code in a scratch snapshot. Both failed as
  described; the source changes and regressions were retained.
- 2026-11-17: Confirmed the CLI reference documents remote-stack lookup through
  checkout by branch or PR, which fetches and establishes local tracking. The
  guidance therefore treats lookup as state-changing and does not call it a
  read-only probe.
- 2026-11-17: Confirmed that merge supports explicit `--merge-method` and
  `--yes`, and issue #467 reproduces a one-PR `submit` success message without
  a remote Stack. Required explicit target/method/confirmation and one-PR
  reporting guidance.
- 2026-11-17: Kept the changes in one ordinary PR because the two source fixes
  and the independent operational guidance do not depend on one another.
- 2026-11-17: The original worktree's deleted `vendor/rescript` checkout was
  preserved. Validation used a scratch copy with the repository's exact
  submodule gitlink rather than restoring that tracked path.
- 2026-11-17: Independent review found and reproduced two regressions introduced
  by the first follow-up patch: nested modules used a later parent scope, and
  namespaced packages leaked unqualified origin keys. Added differential
  regressions for both; module declarations now use lexical parent scopes and
  the combined dependency context receives only namespace-qualified origins.
- 2026-11-17: Review of the corrective patch found the same parent-scope issue
  in recursive module groups. Added constrained recursive-value and recursive
  alias regressions; recursive groups now infer from their declaration-time
  parent plus the group's recursive bindings.
