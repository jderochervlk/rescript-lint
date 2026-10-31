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
