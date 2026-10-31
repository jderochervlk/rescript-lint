# Render-function recognition

Created: 2026-10-22
Last updated: 2026-10-31
Status: Implemented
Issue: https://github.com/jderochervlk/rescript-lint/issues/33

## Purpose and supported behavior

`react/rules-of-hooks` recognizes component bindings annotated
`@react.component`, `@jsx.component`, or `@react.componentWithProps`, and simple
function bindings whose names start with ASCII `A-Z`, including escaped names
such as `\"DrawerContent"`. Uppercase naming permits raw render functions without
requiring component PPX generation. There is no new annotation or configuration.

The [rule reference](../rules/RULES.md#reactrules-of-hooks) is authoritative for
hook naming, custom hooks, wrappers, and placement restrictions. Component
designation permits valid top-level hook calls; it does not exempt conditional
calls or hooks inside ordinary nested event handlers and callbacks.

## Usage

For a props-object render function, the existing linter accepts:

```rescript
type props = {title: string}

let \"DrawerContent" = (props: props) => {
  let (value, _) = React.useState(() => 0)
  React.string(props.title ++ Int.toString(value))
}
```

No component annotation is required. Uppercase naming does not
make `if flag {React.useState(() => 0)}` or
`let onClick = () => React.useState(() => 0)` valid inside the render body.
These are parser-level lint examples, not a promise of type checking or
compatibility with a particular React Native navigation binding.

## Design and boundaries

Binding ownership recognizes the three existing annotations first, custom-hook
names second, and uppercase names third. The pinned parser retains exotic
quoting for uppercase identifiers; the rule uses its `Ext_ident` unwrapping
helper before examining the initial character. Type-constrained simple bindings
and direct `React.memo`/`React.forwardRef` wrappers retain component ownership.

Lowercase names (including unannotated `make`), underscore prefixes, non-ASCII
initials, destructured bindings, and unknown wrappers do not gain ownership.
An uppercase initializer that calls a hook is still invalid: ownership applies
to the function body, not arbitrary initializer expressions. Wrapper comparators,
anonymous callbacks, ordinary named event handlers, and returned anonymous
functions start separate ordinary contexts. Conditional, loop, async, default
argument, and exception restrictions remain unchanged.

Uppercase helpers also qualify regardless of runtime use: this is a syntactic
React naming policy, not type inference or proof that a function renders.
Separately named uppercase render functions nested inside other functions get
their own component context, just as separately named custom hooks do.

**These are compiler component annotations, not lint-only markers.** Do not add
one on the assumption that generated code stays unchanged.

At pinned ReScript commit `679406560d169f1124653ab50795d5077570f078`:

- [`jsx_common.ml`](https://github.com/rescript-lang/rescript/blob/679406560d169f1124653ab50795d5077570f078/compiler/syntax/src/jsx_common.ml)
  recognizes `react.component` and `jsx.component` as component transforms, and
  recognizes `react.componentWithProps` for the props-object transform.
- [`jsx_v4.ml`](https://github.com/rescript-lang/rescript/blob/679406560d169f1124653ab50795d5077570f078/compiler/syntax/src/jsx_v4.ml)
  preserves a single props argument for `componentWithProps`, constrains the
  return to a JSX element, and generates a wrapper for nonrecursive bindings.
- The upstream
  [props-object fixture](https://github.com/rescript-lang/rescript/blob/679406560d169f1124653ab50795d5077570f078/tests/syntax_tests/data/ppx/react/sharedPropsWithProps.res)
  and its
  [expected PPX output](https://github.com/rescript-lang/rescript/blob/679406560d169f1124653ab50795d5077570f078/tests/syntax_tests/data/ppx/react/expected/sharedPropsWithProps.res.txt)
  show that wrapper and return constraint.

The compiler also recognizes `jsx.componentWithProps`, but this linter's
documented annotation set does not include it. Compiler recognition and lint
recognition are separate contracts.

Uppercase recognition itself adds no compiler annotation or generated code.
The existing annotations remain available but are not lint-only solutions.
Check the application's compiler configuration, generated output, and consuming
API before choosing them; parser-level recognition does not establish
navigation-library compatibility.

## Validation

### Uppercase recognition (2026-10-31)

With `OPAMSWITCH=/home/josh/Dev/rescript-linter` and `DUNE_ROOT="$PWD"`:

- `opam exec -- dune exec test/react_rules_of_hooks_test.exe` passed.
- `make check` passed: build, formatting, OCaml lint, and all tests.
- `opam exec -- dune exec rescript-lint -- --format json "$DELTA_SCRATCH_DIR/UppercaseCallback.res"`
  returned `outcome: clean`, exit code 0, and no diagnostics for the issue's
  raw-props reproduction.
- `git diff --check` passed.
- `make coverage` passed: overall 96.61% (8968/9283), hooks 99.44% (178/179).
  The uncovered rule point is the defensive empty-name guard; the parser rejects
  empty quoted identifiers before rule analysis.

The first focused run exposed the parser's retained exotic quoting; the
implementation was corrected to use the pinned parser helper. An attempted empty
quoted identifier fixture was removed because it is invalid syntax. The first
`make check` found stale mutation-exception line numbers, which were updated
without adding exceptions. Formatting was applied with `opam exec -- dune fmt`.
The final checks above passed after these corrections.

The initial submodule clone was interrupted by the command timeout. Fetching the
pinned commit and checking it out detached restored the exact gitlink without
vendor changes or dependency installation. Existing compatible tools were used
without changing their switch or global configuration. npm packaging checks were
not run: no packaging or dependency behavior changed. React Native application
compilation and runtime integration remain outside these parser-level checks.

### Earlier annotation-only policy

On 2026-10-22, with `OPAMSWITCH=/home/josh/Dev/rescript-linter` and
`DUNE_ROOT="$PWD"`:

- `opam exec -- dune exec test/react_rules_of_hooks_test.exe` passed.
- `make check` passed: build, formatting, OCaml lint (zero findings), and tests.
- `make coverage` passed: overall 96.65%; hooks rule 100% (168/168).

After integrating `main` through `6a83ab8` on 2026-10-22, the same focused
executable and exact `make check` passed again. OCaml lint checked 488 sources
with zero findings. Exact `make coverage` passed at 96.63% overall (8950/9262),
with hooks at 100% (171/171). Local documentation-link and whitespace checks
passed. Production OCaml matches the landed implementation; the conflict
resolution only combines the rule-reference wording. Current-head hosted CI
and Codex rereview remain required before merging this integration.

Focused regressions cover unannotated and annotated escaped-uppercase props
functions, conditional calls, and nested event-handler calls. An initial run
failed because the new annotated fixture lacked a required blank line; the
fixture was corrected and all checks rerun successfully. No production OCaml
code changed. npm packaging checks were not applicable. Compiler behavior was
verified by pinned-source and expected-output inspection, not by compiling a
React Native application.

Parent authorized restoration of the absent pinned submodule for validation;
`git submodule update --init --depth 1 vendor/rescript` restored the gitlink's
commit without tracked vendor changes.

## Historical planning record

### Original committed plan: Uppercase render-function recognition

Plan created: 2026-10-22
Plan last updated: 2026-10-22
Original commit: `47384842bc20791db6820c57bdbcef4c33566cc4`

The following is historical intent, superseded by the decision below.

```markdown
# Uppercase render-function recognition

Created: 2026-10-22
Last updated: 2026-10-22
Status: Blocked on policy approval
Issue: https://github.com/jderochervlk/rescript-lint/issues/33
Feature documentation: pending

## Problem and intended outcome

Escaped uppercase render-function bindings currently require component annotations
that may trigger compiler code generation. Allow designated raw props render
functions to use unconditional hooks while continuing to check conditional calls
and nested callbacks.

## Scope and non-goals

Change only render-function ownership recognition, its focused tests, and its
documented contract. Do not change hook callee recognition, callback traversal,
control-flow analysis, suppression policy, compiler behavior, or dependencies.
Other workers own issues #31 and #32.

## Approach and decisions

The current owner classifier accepts component annotations and custom-hook names.
Recommend recognizing simple bindings beginning with ASCII uppercase letters,
including escaped identifiers, in the existing owner classifier. This matches the
React naming convention without adding annotation syntax. It also treats ordinary
uppercase helpers as component candidates; this is a deliberate contract change,
not proof that the function renders React.

An explicit lint-only annotation would avoid that naming-policy tradeoff but adds
a new public designation mechanism. Parent approval is required before choosing
either approach. Preserve existing per-function restrictions and callback resets.
Do not grant ownership to arbitrary initializer expressions or destructuring.

## Implementation steps

- [ ] Obtain parent approval of recognition policy.
- [ ] Extend the narrow owner classifier without changing traversal.
- [ ] Add positive raw-props/typed-binding cases and negative lowercase,
      conditional, nested callback, async, initializer, and destructuring cases.
- [ ] Update the rule contract and promote this plan into living feature docs,
      preserving this original planning record and creation date.

## Validation

Planned: focused `opam exec -- dune runtest test/rules/pedantic`, `make check`,
and `make coverage`. Inspect the final diff and commit only task-owned files.
No implementation checks have run yet.

## Open questions and remaining work

Await parent decision on uppercase naming versus explicit lint-only designation.
The pre-existing `vendor/rescript` deletion must not be committed or repaired.
Do not install global tools. Push the unique branch without force, open a PR
against main, request Codex review, and hand pending review back to the parent.
```

### 2026-10-22 decision and delivery

The user chose: "Yes, keep annotation based recognition, no new rule, document it."
This superseded uppercase inference, the classifier change, and the broader test
matrix. The delivered scope is existing-policy documentation and four focused
regressions. Parent subsequently authorized restoring the pinned vendor submodule
for checks. Validation used the actual executable target because `test/dune`
owns the test despite its source being under `test/rules/pedantic`.
This document promotes the plan, preserving its original contents and creation
date in the final tree as required by PR #36's planning workflow.

### Integrate annotation-based render recognition documentation

Plan created: 2026-10-22
Plan last updated: 2026-10-22

Original committed integration plan (`16c27a3`), preserved verbatim:

```markdown
# Integrate annotation-based render recognition documentation

Created: 2026-10-22
Last updated: 2026-10-22
Status: Planned
Issue: https://github.com/jderochervlk/rescript-lint/issues/33
Feature documentation: [Render-function recognition](../features/render-function-recognition.md)
Related PR: https://github.com/jderochervlk/rescript-lint/pull/43

## Problem and intended outcome

PR #43 has a documentation conflict with the hook naming and ownership changes
that landed in PRs #37 and #40. Preserve those changes and the user's decision
to retain annotation-based component recognition, without a new lint rule or
uppercase-name inference.

## Scope and non-goals

Normally merge current `main`, reconcile the rule-reference conflict, and
verify the combined documentation and existing regressions. Do not change rule
implementation, annotations, dependency versions, or validation policies.

## Approach and decisions

The component-recognition contract must retain the supported annotations and
exact-`use` custom-hook ownership from `main`. Add PR #43's guidance about
unannotated render functions and annotation code-generation effects beside it.
Preserve the original plan and record this integration in the living feature
document. No history rewriting or force push.

## Implementation steps

- [ ] Merge current `main` normally and resolve only the documented conflict.
- [ ] Check that both hook fixes and all render-recognition regressions remain.
- [ ] Run focused hooks tests, exact `make check`, coverage, and link checks.
- [ ] Consolidate this plan into the existing feature's historical record.
- [ ] Push the integration and obtain current-head CI and Codex rereview.

## Validation

Planned commands use the existing tools without modifying their switch:
`OPAMSWITCH=/home/josh/Dev/rescript-linter DUNE_ROOT="$PWD"`.
Run `opam exec -- dune exec test/react_rules_of_hooks_test.exe`,
`make check`, `make coverage`, and `git diff --check`. Restore only the exact
pinned parser checkout inside this worktree if it is missing.

## Open questions and remaining work

No product decisions remain. Merge only after exact-head CI passes, actual
Codex review completes, all comments are addressed and resolved, and a fresh
pre-merge check confirms the intended head.
```

### 2026-10-22 integration delivery

Normally merged the landed changes through `6a83ab8`. The sole conflict was in
the rule-reference paragraph: retained qualified-`use` classification and
exact-`use` hook ownership alongside annotation-only component recognition.
Hook tests merged without manual changes. The exact pinned parser checkout
was restored locally for validation without changing its gitlink or the shared
development switch. All local checks above passed; hosted CI and actual Codex
rereview of the pushed integration are still pending, not claimed complete.

### Uppercase render bindings

Plan created: 2026-10-31
Plan last updated: 2026-10-31

The following committed plan is historical intent, now implemented. The current
request explicitly supersedes the earlier annotation-only decision.

```markdown
# Uppercase render bindings

Created: 2026-10-31
Last updated: 2026-10-31
Status: Planned
Issue: https://github.com/jderochervlk/rescript-lint/issues/33
Feature documentation: ../features/render-function-recognition.md

## Problem and intended outcome

Escaped uppercase render bindings currently require component annotations.
Allow their unconditional hooks without requiring component PPX generation.

## Scope and non-goals

Recognize simple bindings whose parsed name starts with ASCII A-Z. Preserve
annotations and custom-hook semantics, conditional checks, and fresh callback
contexts. Do not infer aliases, destructured bindings, or unknown wrappers.

## Approach and decisions

Extend binding ownership rather than traversal. Treat uppercase names as component
owners, including the existing direct React.memo/React.forwardRef handling.
This naming policy matches React conventions without adding configuration or
annotations. It does not prove how the function is used at runtime.

## Implementation steps

- Extend ownership and add positive and negative parser-level regression tests.
- Update the rule reference and consolidate this plan into render recognition docs.

## Validation

Run `opam exec -- dune exec test/react_rules_of_hooks_test.exe`, `make check`,
and `make coverage` with an existing compatible Opam switch. Inspect the final
diff and ensure only issue-specific commits are ahead of origin/main.

## Open questions and remaining work

Initialize the pinned parser submodule and verify available coverage tools.
```

### 2026-10-31 implementation delivery

Extended only binding ownership, retaining hook classification and traversal.
Added raw props, constrained binding, module, single-letter, wrapper, conditional,
loop, callback, async, default argument, initializer, destructuring, and naming
boundary regressions. Existing annotated-component and custom-hook cases still
pass. Validation results and limitations are recorded above. No implementation
work remains; hosted CI and maintainer review follow PR publication.
