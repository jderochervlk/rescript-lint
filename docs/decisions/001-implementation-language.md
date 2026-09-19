# ADR 001: Initial Implementation Language

Status: Accepted for the parser spike

Date: 2026-09-19

## Context

The linter needs accurate ReScript parsing, source locations, useful diagnostics, and a path to semantic rules. The two candidate implementation languages are OCaml and Rust.

## Decision

Start in OCaml, using the ReScript compiler’s parser and AST where the dependency boundary allows it. Keep the linter’s domain model, rule contract, and reporting interfaces separate from those compiler-specific types.

## Why OCaml first

- ReScript’s official compiler is written in OCaml.
- Reusing the official parser avoids creating a second grammar that can drift from the language.
- The compiler already has the most authoritative AST and source-location behavior.
- Existing ReScript linter prior art uses Dune and `Parsetree`, which lowers the discovery cost for a first prototype.

## Costs and risks

- OCaml toolchain installation is a higher barrier for many users than downloading a Rust binary.
- Compiler-internal APIs may be difficult to package and may change between ReScript versions.
- Distribution and cross-compilation may be less convenient than Cargo-based Rust distribution.

## When Rust becomes the better choice

Revisit Rust if the spike shows that the official parser cannot be consumed without vendoring unstable internals, or if standalone cross-platform distribution and editor responsiveness dominate the product requirements. Rust would then likely need either a maintained ReScript parser port or an adapter around the official Tree-sitter grammar, with an explicit plan for syntax compatibility and error recovery.

## Consequence

The first milestone must measure integration cost instead of debating language choice abstractly. We should not write a new parser until reuse of the official parser and the Tree-sitter grammar have both been evaluated against representative ReScript syntax.

