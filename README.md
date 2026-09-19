# ReScript Linter

An extensible linter for [ReScript](https://rescript-lang.org/).

This repository is at the design and parser-spike stage. The first implementation target is a small command-line linter that can parse ReScript, run independent rules, and report editor-friendly diagnostics without needing to compile the whole project.

## Current direction

Start with OCaml and the official ReScript compiler syntax/AST. ReScript itself is implemented in OCaml, so this gives the linter the best chance of matching the language as it evolves and of preserving source locations and compiler semantics. Keep the rule engine and diagnostic model independent from compiler integration so a Rust front end remains possible later.

This is a provisional decision. The first milestone is a parser spike, not a promise to stay with OCaml forever.

## Project plan

See [docs/PLAN.md](docs/PLAN.md) for milestones, boundaries, and open questions. The language choice is recorded in [docs/decisions/001-implementation-language.md](docs/decisions/001-implementation-language.md).

## Development status

No build toolchain is required yet. The initial spike will require an OCaml switch with Dune and a pinned ReScript compiler source or compiler-libs package.

