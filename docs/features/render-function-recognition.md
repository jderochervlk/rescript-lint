# Render-function recognition

Created: 2026-10-22
Last updated: 2026-10-22
Status: Implemented (existing policy documented; no recognition change)
Issue: https://github.com/jderochervlk/rescript-lint/issues/33

## Purpose and supported behavior

`react/rules-of-hooks` recognizes component bindings annotated
`@react.component`, `@jsx.component`, or `@react.componentWithProps`.
Uppercase names alone, including escaped names such as `\"DrawerContent"`, do not
designate render functions. There is no new lint-only annotation, naming option,
or annotation-enforcement rule.

The [rule reference](../rules/RULES.md#reactrules-of-hooks) is authoritative for
hook naming, custom hooks, wrappers, and placement restrictions. Component
designation permits valid top-level hook calls; it does not exempt conditional
calls or hooks inside ordinary nested event handlers and callbacks.

## Usage

For a props-object render function, the existing linter accepts:

```rescript
type props = {title: string}

@react.componentWithProps
let \"DrawerContent" = (props: props) => {
  let (value, _) = React.useState(() => 0)
  React.string(props.title ++ Int.toString(value))
}
```

Removing the annotation produces a hook-placement finding. Adding it does not
make `if flag {React.useState(() => 0)}` or
`let onClick = () => React.useState(() => 0)` valid inside the render body.
These are parser-level lint examples, not a promise of type checking or
compatibility with a particular React Native navigation binding.

## Design and boundaries

The user chose to retain annotation-based recognition rather than infer component
ownership from escaped-uppercase names. No implementation change is needed:
the existing owner classifier already accepts the three annotations.

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

This policy does not provide the requested combination of an unannotated raw
render function and no component code generation. If avoiding PPX effects is a
hard requirement, the existing annotations are not a lint-only solution. Check
the application's compiler configuration, generated output, and consuming API
before choosing them; this change does not establish navigation-library
compatibility.

## Validation

On 2026-10-22, with `OPAMSWITCH=/home/josh/Dev/rescript-linter` and
`DUNE_ROOT="$PWD"`:

- `opam exec -- dune exec test/react_rules_of_hooks_test.exe` passed.
- `make check` passed: build, formatting, OCaml lint (zero findings), and tests.
- `make coverage` passed: overall 96.65%; hooks rule 100% (168/168).

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
