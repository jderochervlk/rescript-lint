# Literal String Semantics Work Log

## Pinned Parser Evidence

- The linter parses with `for_printer:true`. Ordinary strings use
  `Pconst_string (raw, None)` and preserve escape spelling, rather than containing
  the decoded runtime string (`res_core.ml`, `parse_constant`).
- The scanner preserves escapes except three-digit decimal escapes, which it
  converts to hexadecimal spelling (`res_scanner.ml`, string scanning).
- The compiler's `Ast_utf8_string.transform` validates/prepares emitted strings;
  it is not a decoded-value API. `Js_exp_make.str_equal` compares identical raw
  spellings, but only folds different raw spellings when both are simple ASCII
  without escapes. No exported complete JavaScript string decoder was found.
- Character and template literals have distinct delimiters. Neither will be
  passed through the ordinary-string helper.

## Approved Bounded Design

- Add an opaque `Literal_string.t` with `decode`, `equal`, and `compare`.
  Use the existing Yojson dependency for JSON-compatible escapes, then validate
  scalar UTF-8 and convert with the standard library's UTF-16BE encoder.
- Lexicographic UTF-16BE keys match JavaScript UTF-16 code-unit ordering,
  including non-BMP values whose ordering differs from UTF-8 byte ordering.
- Invalid UTF-8, unpaired surrogate values, and unsupported escapes return
  `None`. No handwritten JavaScript decoder and no guessed value on failure.
- Hex escapes, braced Unicode escapes, identity escapes, vertical-tab/null
  escapes, decimal escapes rewritten by the scanner, and line continuations
  remain explicitly outside the initial supported subset.
- Change only the string scalar branch of `Control_flow_rules`. Preserve all
  non-string folding and structural branch equality. `Expression_rules` remains
  unchanged: two syntactic string literals already satisfy `no-useless-concat`,
  even when their escape spellings are unsupported for value decoding.

## Verification Plan

- Equivalent ordinary and Unicode-escaped strings; all JSON short escapes;
  distinct raw backslash text versus decoded control characters; empty/prefix
  ordering; composed versus decomposed Unicode without normalization.
- Valid multi-byte scalars and surrogate pairs; isolated/reversed surrogates;
  malformed UTF-8; unsupported escape forms; invalid JSON spelling.
- Non-BMP versus BMP ordering and opposite comparisons, checking diagnostic
  truth values rather than merely the presence of a finding.
- Parser regressions for escaped comparisons, raw Unicode, templates, decimal
  normalization, and unsupported escapes. Existing non-string tests remain.
- Production edits wait until the preceding index release is packaged/pushed.
  Parent serializes test/build/coverage commands and owns test registration.
- Verified representative values with local Node: `a` equals `\u0061`, newline
  equals `\u000a`, U+10000 sorts before U+E000, composed/decomposed accented
  strings differ, and literal backslash-plus-`b` differs from backspace.
- Yojson's pinned decoder joins high/low surrogate pairs, but its lone-low
  surrogate path requires the additional UTF-8 scalar validation. The ReScript
  scanner rejects surrogate escapes individually, so surrogate-pair behavior is
  a helper boundary test rather than a claimed accepted source syntax example.

## Implementation

- Added `Literal_string`, using the documented Yojson reader and an exact lexer
  end-position check. A premature closing quote followed by JSON comments cannot
  silently produce a successful shorter value.
- Decoded values are opaque validated UTF-16BE keys. UTF-8 decoding and UTF-16
  encoding use OCaml standard-library APIs; mutable buffers are confined to one
  conversion call and never escape.
- Updated only `Control_flow_rules` string scalars. Added 52 helper checks plus
  parser-backed tests for truth messages, literal representation, safe unknown
  cases, Unicode ordering, and template exclusions. Existing expression rules
  and all non-string semantics were left unchanged.
- Source files formatted. Parent owns coordinated builds, test registration,
  coverage, and final integration verification.
- First targeted run grouped all escaped-positive failures at the lexer-end
  check. Yojson overrides `Lexing.engine` and intentionally does not update
  position records, so `Lexing.lexeme_end` remains stale. Corrected the check to
  use the documented lexbuf byte cursor (`lex_abs_pos + lex_curr_pos`), retaining
  exact end-of-input validation and the comment/extra-token negative tests.
- The corrected helper's 52 cases and parser-backed comparison suite pass.
  Parent compiled a real pinned-compiler fixture and verified JSON CLI output:
  `"a" == "\u0061"` reports constant equality, while a braced-Unicode comparison
  remains unknown as documented. Full batch coverage is coordinated separately.
- Final coordinated `make check` and coverage gate passed: `Literal_string`
  100%, `Control_flow_rules` 97.20%, overall 95.55% (7403/7748). Production frozen
  for release verification; no unsupported escape forms were broadened.
