---
name: functional-code-style
description: Apply functional design to OCaml application and domain logic, including explicit effects, algebraic data types, and typed error handling.
---

# Functional Code Style For OCaml

Follow the repository's module boundaries, naming, formatting, and test conventions. Preserve behavior unless the requested change requires otherwise. This repository targets OCaml 5.5 and builds with Dune; use existing dependencies and standard-library facilities before proposing a new package.

## Design

- Keep domain transformations pure where practical, and isolate filesystem, process, network, clock, and other effects at explicit boundaries.
- Give each function one clear responsibility. Prefer small functions that compose through ordinary application, pattern matching, and the standard `|>` operator when it makes data flow easier to read.
- Prefer immutable records and values. Keep mutation local to an algorithm or effect boundary; do not expose mutable state as part of a domain interface without a clear need.
- Represent domain states with variants and records. Use exhaustive pattern matching and make invalid combinations difficult to construct.
- Use module signatures and `.mli` files to hide implementation details when a module has an invariant or a meaningful public boundary. Keep interfaces focused on the operations callers need.
- Decode and validate untrusted input at the boundary before passing it into domain logic. Reuse the project's existing decoders and error types.
- Make dependencies explicit through function arguments or module boundaries rather than hidden global state.
- Prefer structural decomposition over deeply nested matches or long argument lists. Use labeled arguments where they clarify call sites or distinguish optional configuration.
- Avoid arbitrary line-count or complexity limits. Split code when a function's purpose, control flow, or failure behavior becomes difficult to follow.

## Errors And Effects

- Represent expected failures with the standard `result` type and a specific error variant or record. Use `option` only when absence is the complete meaning of the outcome.
- Preserve actionable context in errors, such as the filename, operation, or invalid field. Do not replace distinct failures with strings until a presentation boundary needs them.
- Do not use exceptions for routine validation or expected operational failures. Catch exceptions at boundaries where OCaml libraries report I/O or protocol failures, then convert them to the module's error type.
- Let exceptions propagate only when the calling contract deliberately uses exceptions or when an invariant failure is genuinely unexpected.
- Keep input/output in CLI, filesystem, process, and protocol adapters. Pass values or typed errors back to the functional core.

## Verification

- Add focused tests for successful behavior, expected errors, and important boundary cases.
- Run the narrowest relevant test while iterating, then use `make check` for the repository's build, formatting, and test gates.
- Keep enabled compiler warnings clean. Do not silence warnings or weaken checks to make a change pass.
