---
name: writing-functions
description: Write clear, composable OCaml functions with explicit types, readable pattern matching, and intentional error handling.
---

# Writing OCaml Functions

- Give a function one clear purpose and keep its inputs and outputs explicit.
- Prefer a small number of meaningful arguments. Use labeled arguments for configuration or when labels make call sites easier to understand.
- Let types describe the contract. Prefer a domain-specific variant or record over loosely related booleans, sentinel values, or stringly typed options.
- Use pattern matching to handle variants, options, and results exhaustively. Keep branches simple by moving distinct work into named helpers.
- Use `List.map`, `List.filter_map`, `List.fold_left`, and other standard-library functions when they express the operation clearly. Use recursion when the traversal needs state or structure that a combinator would obscure.
- Make recursive functions structurally clear. Use tail recursion when processing large inputs with an accumulating result; preserve input order deliberately when building lists.
- Use `|>` when it clarifies a sequence of transformations. Avoid adding a pipeline helper dependency or a pipeline just to shorten syntax.
- Return `('a, error) result` for expected failures and define errors with variants or records that retain useful context. Use `option` for ordinary absence.
- Do not raise exceptions for expected failures. At I/O and third-party library boundaries, catch expected exceptions and convert them into the local error type; preserve unexpected exceptions when the contract calls for propagation.
- Keep side effects visible in the function's role and name. Separate parsing, validation, and transformation from file access or output when that makes behavior easier to test.
- Follow nearby `.ml` and `.mli` conventions, including exposed types, documentation comments, and OCamlformat output.
