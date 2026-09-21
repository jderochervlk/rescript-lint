# JSX and React DOM Rule Work Log

## Scope

- Implement all 34 catalogued JSX accessibility rules and the first eight React
  DOM/list rules behind an explicit `react-dom` JSX runtime adapter.
- Apply functional-code-style, writing-functions, and react-component-style.
- Keep all new rules opt-in. No runtime dependencies, fixes, or compiler changes.
- Shared model preserves real JSX nodes, fragments, intrinsic/custom tag identity,
  optional props, property expressions, spreads, and source locations. Spreads
  produce unknown property values, never missing-property assertions.

## Evidence

- Parser: pinned `vendor/rescript/compiler/ml/parsetree.ml` and JSX parsing in
  `vendor/rescript/compiler/syntax/src/res_core.ml`.
- DOM spelling/types: pinned `vendor/rescript/packages/@rescript/runtime/JsxDOM.res`;
  React adapter audit also checked installed `@rescript/react` 0.15.0 under the
  existing temporary compiler-audit project.
- ARIA role tables are derived from the immutable
  [WAI-ARIA 1.2 Recommendation](https://www.w3.org/TR/2023/REC-wai-aria-1.2-20230606/).
  A standard-library HTML parser extracted required, supported, inherited, and
  prohibited properties for all 82 concrete roles; abstract roles are excluded.
- HTML semantics follow [ARIA in HTML](https://www.w3.org/TR/html-aria/) and the
  [HTML autofill grammar](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#autofill).

## Conservative boundaries

- Custom components and hyphenated custom elements do not receive DOM rules.
- Dynamic/optional properties and spreads suppress absence/value conclusions.
- File-local module shadowing or opens disable the matching React/Array API
  interpretation; list index checks follow actual callback bindings.
- Context-dependent HTML implicit roles are omitted when ancestry/value evidence
  is insufficient. This is local source analysis, not a rendered accessibility
  tree audit.

## Progress and follow-ups

- Added the reusable JSX model and generated ARIA semantics table.
- Rule implementations and fixture coverage are in progress; root coordinates
  builds and integration to avoid concurrent dune execution.

### First integrated verification and precision audit

- All 42 rules compiled and their initial focused tests passed in the root's
  coordinated full-suite run.
- Initial per-file execution-point coverage passed the repository gate:
  JSX model 90.84%, accessibility rules 91.12%, React DOM rules 90.87%.
- Grouped precision findings before correction: custom children and dynamic
  descendant names must remain unknown; empty associated labels must not count
  as names; dynamic roles must not establish noninteractive semantics; dynamic
  image alternatives and select settings must not establish fixed native roles;
  hidden/dynamically hidden ancestors need visibility-aware suppression.
- Added meaningful native-role, focus, dynamic-content, and all-82-concrete-role
  validation cases as part of this grouped follow-up.
- Root's compiled catalog-example audit found three misses caused by the
  conservative unknown-open boundary (`open Prelude`). Both check APIs now
  accept project module signatures: known opens retain React/Array/Int identity
  unless they export a conflicting module. Unknown opens remain conservative.
- Audited runtime callback definitions directly. Standard Array/List indexed
  maps receive `(item, index)`; Belt Array/List indexed maps receive
  `(index, item)`. Fixed the Belt index interpretation and added both List
  adapters plus negative tests proving the item is not misidentified.
- Functor module parameters and project-local modules now also quarantine
  corresponding runtime API names. Typed callback parameter patterns retain
  their lexical index identity.
- Focus analysis excludes hidden inputs even when they carry tabIndex.
- Final native-role audit found three contextual cases: omitted input type with
  a datalist is still a combobox; dynamic section/form labels cannot prove a
  named landmark; an explicitly named image is not decorative solely because
  alt is empty. Corrected all three with positive and negative regressions.
