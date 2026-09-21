# Policy Rule Work Log

## Scope and design

- Read the candidate inventory, rule examples, existing AST rules and tests,
  parser implementation, compiler function representation, and comment API.
- Applied the functional-code-style and writing-functions skills.
- Added six independently selectable policies through a single document check:
  `no-empty-function`, `no-empty-file`, `no-warning-comments`, `max-nesting`,
  `max-params`, and `max-lines-per-function`.
- Defaults for limits are four control-flow levels, five parameters, and fifty
  physical function lines. Root integration owns opt-in registration/config.
- No dependencies or broad parser changes are needed.

## Behavioral choices

- Empty functions are direct unit bodies. An explicit
  `: unit` return annotation documents and exempts an intentional no-op.
- Empty implementations include whitespace/comment-only and module-attribute-only
  files. Empty interfaces are deliberately exempt.
- Warning terms are case-insensitive whole words TODO, FIXME, and HACK, checked
  only in parsed comments. Each comment receives at most one finding.
- Nesting counts conditionals, switches, exception handlers, and loops. Else-if
  chains retain their current depth; each function starts at zero. Report the
  first level beyond the configured limit, avoiding cascaded inner diagnostics.
- Function metrics consume exactly the parser's declared arity. Labeled and
  optional parameters each count once, returned functions count separately, and
  the implicit unit argument in `() => ...` counts as zero parameters.
- Function lines include blank and comment lines within the function span.
  No automatic fixes are provided for these project policy decisions.

## Deferred limitations

- Custom comment term lists and generated-file detection are not implemented in
  this module. Generated-file exclusions remain a configuration follow-up.
- An annotation on an outer binding type is not the documented no-op exemption;
  use the direct function return annotation (`() : unit => ()`).

## Verification

- Added 64 focused positive/negative, boundary, arity, nested-function,
  documentation, and diagnostic-range checks. Builds are coordinated by the
  root agent; owned OCaml files have been formatted with the repository tool.

### First coordinated test run

- Compilation passed; four fixture failures were recorded before correction.
- Empty `{}` expressions are empty records in this parser, not empty unit
  blocks. Keep them valid rather than treating a returned record as a no-op.
- Documentation comments are represented as `res.doc` AST attributes and are
  absent from `Parser.document.comments`. Add a dedicated read-only attribute
  pass, checking source delimiters to exclude manually written annotations.
- Single-line comment locations begin after `//`; normalize the diagnostic to
  include that delimiter. Multiline comment ranges already include delimiters.
- The follow-up run passed all prior failures. An additional parameter-doc
  fixture was rejected by the parser; use a supported record-field doc comment
  to exercise nested documentation attributes instead.

## Final coordinated verification

- All 64 focused policy checks passed in the full suite.
- Policy module execution-point coverage: 98.37% (121/123).
- LSP/watch integration preserved optional policies across edits and reruns.
- Release build passed. See RULE_WORK_LOG.md for the shared final report.
