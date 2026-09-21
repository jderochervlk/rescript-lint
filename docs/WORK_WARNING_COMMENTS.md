# Warning Comment Policy Work Log

## Contract

- Added a validated, abstract `Policy_rules.warning_policy` and optional
  `check ~warning_policy`. Existing callers retain the original defaults:
  TODO, FIXME, and HACK, matched case-insensitively as whole words.
- Custom terms replace, rather than extend, the defaults. At least one term
  is required. Every term must be an ASCII identifier starting with a letter;
  subsequent letters, digits, and underscores are allowed. Terms normalize to
  uppercase, preserve configured order, and reject case-insensitive duplicates.
  Empty, whitespace, punctuation, multiword, non-ASCII, and digit/underscore
  initial terms are rejected with errors, not silently ignored.
- Allowed contexts are `Line`, `Block`, and `Documentation`, corresponding to
  JSON names `line`, `block`, and `documentation`. An allowed context exempts
  its whole parsed comment. Defaults exempt none; explicitly allowing all three
  is valid. Duplicate contexts are rejected. There are no text-based suppression
  patterns and no new inline disabling mechanism.
- Line comments use parser comment styles; ordinary block comments use the
  block style. Both attached `/** */` and module `/*** */` documentation use
  the documentation context, including documentation represented by parser
  attributes. Explicit `@res.doc("...")` attributes remain non-comments.
- Matching retains the previous conservative byte-level boundary contract:
  ASCII letters, digits, underscores, and every UTF-8 high byte are word
  characters. Thus `TODOe`, `TODO_`, `TODO1`, and TODO adjacent to non-ASCII
  text do not match. Even Unicode punctuation directly adjacent to TODO is
  conservatively considered a word byte. This is not Unicode word segmentation
  or Unicode case folding. ASCII punctuation/whitespace provide boundaries.

## Implementation

- Applied functional-code-style and writing-functions. Configuration validation
  returns errors as values, and the policy remains immutable and abstract.
- Existing comment scanning and source ranges are preserved. Strings and
  explicit attribute text are not scanned. Warning messages list configured
  terms in stable order, once each, with one diagnostic per matching comment.
- Exported `default_warning_terms`, `default_warning_policy`, `comment_context`,
  and `warning_policy ~terms ~allowed_contexts` for root configuration wiring.
- Root owns `warningComments` decoding, project options, linter integration,
  test registration, and all Dune builds. No production dependencies added.

## Verification and Follow-Up

- Added dedicated cases for defaults, custom terms, normalization, validation,
  all parsed contexts and combinations, doc attributes, interfaces, synthetic
  parser doc styles, lexical boundaries including UTF-8, string exclusion,
  message order, and exact byte ranges.
- Formatting and whitespace checks run locally; compilation, execution, and
  coverage await root verification. No concurrent Dune invocation.
- No implementation blockers identified. Non-ASCII configured terms and full
  Unicode word segmentation are explicitly outside this bounded policy.

## Configuration Integration Follow-Up

- Added the focused `Warning_config` decoder, project option default, and linter
  forwarding. Root delegated these narrow integration changes after completing
  throws-dependency configuration; existing dependency options are preserved.
- `warningComments` must be an object with optional `terms` and
  `allowedContexts`. Missing fields use their original defaults; every supplied
  object is a complete replacement policy, not a merge with the previous policy.
  Unknown and duplicate properties, malformed arrays/elements, unknown contexts,
  and constructor validation errors are rejected. JSON `null` is not a policy.
- Added configuration-to-linter behavior cases, strict decoder failure cases,
  replacement-policy semantics, preserved disabled-rule behavior, and a
  dependency-option preservation regression.
- First root test run found one new range fixture error: `// REVIEW_ME` is 12
  bytes, not 13. The parser correctly excludes the newline. Corrected the exact
  expected end offset to 12 and additionally asserted line 1, column 13; no
  production range behavior changed. All other initial warning cases passed.
- Final root `make check` and coverage passed. Overall coverage was 95.47%
  (7,206/7,548); Warning_config, configuration, and linter reached 100%, while
  Policy_rules reached 97.59%. Production is frozen for root packaging gates.
