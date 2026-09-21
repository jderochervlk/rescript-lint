# ADR 002: LSP Protocol Library

Status: accepted, 2026-09-20.

## Context

The language server needs maintained LSP message types, JSON conversion,
file-URI handling, and JSON-RPC framing. Hand-written protocol objects would make
capability negotiation and evolving message shapes unnecessarily fragile.

The evaluated OCaml choices were the `lsp`/`jsonrpc` packages maintained with
`ocaml-lsp`, and `linol`. Both support the repository's OCaml version. `linol`
provides a higher-level server framework but brings an additional runtime model
and more policy than this sequential server currently needs.

## Decision

Pin `lsp` and `jsonrpc` at matching version 1.27.0.

- Use `Lsp.Types`, typed request/notification decoders, diagnostics, and URI
  conversion.
- Use `Lsp.Io.Make` for standard framing behavior behind a repository-owned
  synchronous channel adapter.
- Enforce header and message-size limits in that adapter because the library's
  framing functor does not impose them.
- Keep lifecycle and document handling in a pure repository-owned reducer. The
  protocol library does not own lint behavior, concurrency, or process policy.
- Record `lsp`, `jsonrpc`, `yojson`, `ppx_yojson_conv_lib`, and `uutf` in the
  native npm source/license bundle.

## Consequences

Protocol shapes and URI escaping follow a maintained implementation used by the
OCaml LSP ecosystem. The server remains small and synchronous, with no async
runtime dependency. Upgrading either primary package requires upgrading both to
the same version, reviewing generated protocol changes, rerunning transcript and
Unicode tests, and refreshing the distribution inventory.
