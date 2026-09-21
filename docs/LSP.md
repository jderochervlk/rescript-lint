# Language Server Plan

Plan status: active, 2026-09-20. This document defines the implementation
sequence and acceptance criteria for exposing `rescript-lint` diagnostics to
editors. The core implementation for Slices 1-2 is runnable and has automated
protocol coverage; editor validation and distribution work remain.

Current implementation:

- immutable open-document values and a URI-keyed document store;
- monotonic document-version enforcement;
- exact UTF-8 and UTF-16 conversion from diagnostic byte offsets;
- structured extraction of parse and analysis diagnostics from `Lint_error`;
- pinned `lsp`/`jsonrpc` protocol types and URI decoding;
- bounded stdio framing and a pure lifecycle reducer;
- initialize, full-document synchronization, push diagnostics, shutdown, and
  exit through `rescript-lint lsp --stdio`;
- verified npm source/license inventory and local rebuild/relink coverage for
  the added protocol dependencies;
- a Zed adapter that registers `rescript-lint` beside the existing ReScript
  language server, uses PATH or a user binary override before npm installation,
  and keeps the two package versions independent.

The runnable server, transcript suite, and Zed development adapter are
implemented. Live Zed interoperability, performance measurements, prerelease
packaging, and editor distribution remain outstanding.

## Outcome

Ship one editor-independent language server in the existing native binary:

```text
rescript-lint lsp --stdio
```

The first client will be Zed. VS Code and other LSP-capable editors should use
the same process and protocol behavior rather than acquiring editor-specific
lint implementations.

The first useful release publishes the current parser, rule, and analysis
diagnostics for open `.res` and `.resi` buffers, including unsaved text. It does
not provide completion, navigation, type information, formatting, or project-wide
analysis. ReScript's existing language server remains responsible for those
features.

## Decisions

1. The LSP server is a subcommand of the existing native executable. Packaging,
   versioning, licenses, platform selection, and the Node launcher remain shared
   with the CLI.
2. CLI watch mode is not used by the language server. Editors already send
   `didOpen`, `didChange`, `didSave`, and `didClose` notifications. The in-memory
   editor buffer is authoritative while a document is open.
3. The initial server uses LSP push diagnostics through
   `textDocument/publishDiagnostics`. Pull diagnostics can be evaluated later if
   a client or performance need justifies them.
4. The server requests full-document synchronization first. Full text keeps the
   document reducer and source ranges simple, while clients are required to
   support full synchronization. Incremental synchronization is a later
   optimization, not part of the first release.
5. The server prefers `utf-8` position encoding when the client offers it and
   otherwise supports the required `utf-16` fallback. Internal byte offsets are
   never sent directly without conversion.
6. The first implementation is sequential. Every accepted document version is
   analyzed before the next protocol message. Add coalescing or background work
   only after measurements show that synchronous analysis harms editing.
7. Zed support extends the existing `rescript-lang/rescript-zed` extension with
   a second language server. Do not create a competing ReScript grammar or
   language definition.
8. The existing `@rescript/language-server` continues to run beside this server.
   It owns compiler-backed language intelligence; `rescript-lint` owns its rule
   diagnostics and fixes.

## Dependency Decision

Protocol handling should use maintained protocol types rather than ad hoc JSON
objects. The recommended starting point is the matching stable versions of the
OCaml `lsp` and `jsonrpc` packages maintained in `ocaml/ocaml-lsp`. Version
`1.27.0` currently supports this repository's OCaml and Dune versions. `lsp` is
IO-independent, which fits a small explicit stdio adapter.

The dependency gate was approved on 2026-09-20. The project pins `lsp` and
`jsonrpc` 1.27.0 and records their linked dependency sources and licenses in the
npm distribution inventory. See
[ADR 002](decisions/002-lsp-protocol-library.md) for the decision.

Remaining validation:

- Install the adapter as a Zed dev extension and complete initialize, open,
  publish, shutdown, and exit against the editor.
- Repeat package and source-bundle verification for every supported release
  target.
- Record startup, lint latency, and binary-size measurements before prerelease.

Do not implement protocol types, JSON parsing, or URI parsing with string
concatenation. A framing adapter, if needed, may parse ASCII headers narrowly,
cap header/body sizes, and delegate JSON decoding to the selected library.

## Architecture

```text
Zed / VS Code / another LSP client
              |
      JSON-RPC over stdio
              |
      Lsp_transport (framing only)
              |
       Lsp_server (lifecycle)
              |
    Lsp_document_store (versions/text)
              |
       Lsp_analysis_adapter
              |
       Linter.lint_source
              |
 parser + rules + typed analysis errors
```

The transport owns bytes, headers, JSON-RPC envelopes, and serialized writes.
The server owns protocol lifecycle and maps messages to state transitions. The
document store owns open buffer text and versions. The analysis adapter owns URI,
position, diagnostic, and fix conversion. The existing linter remains unaware of
LSP.

Model the server as a state transition with explicit effects:

```text
handle : server_state -> client_message -> server_state * effect list
```

Representative effects are `Send_response`, `Publish_diagnostics`, `Log`, and
`Exit`. Transport IO executes effects at the outer boundary. Expected protocol,
URI, document, and analysis failures remain tagged values; they do not become
uncaught exceptions.

Suggested modules:

```text
lib/lsp_position.ml       byte offsets and negotiated LSP positions
lib/lsp_uri.ml            file URI decoding and normalized paths
lib/lsp_document.ml       immutable open-document model
lib/lsp_diagnostics.ml    lint result to LSP diagnostic conversion
lib/lsp_server.ml         lifecycle and message reducer
lib/lsp_transport.ml      stdio framing and JSON-RPC boundary
bin/main.ml               `lsp --stdio` command dispatch
```

Names may change to match the selected library, but these ownership boundaries
should remain visible.

## Server State

Use tagged lifecycle states so invalid message ordering is explicit:

- `Waiting_for_initialize`
- `Running` with client capabilities, negotiated position encoding, workspace
  folders, and an immutable URI-to-document map
- `Shutdown_requested`
- `Stopped`

An open document contains:

- the original document URI;
- an optional decoded local path;
- the LSP language id;
- the monotonically increasing client version;
- the complete current text;
- `Source.Implementation` or `Source.Interface` derived from the path suffix;
- a line index used for position conversion.

Key documents by their URI, not by a lossy path conversion. Decode a local path
only when constructing `Source.filename` or later accessing project metadata.
Ignore unsupported URI schemes with an actionable log message and no process
failure.

## Protocol Surface: First Release

### Lifecycle

Implement:

- `initialize`
- `initialized`
- `shutdown`
- `exit`
- `$/setTrace` as a harmless accepted notification if the library exposes it

Advertise only implemented capabilities. Return method-not-found for unsupported
requests. Never advertise completion, hover, navigation, formatting, semantic
tokens, or workspace commands.

Exit with status `0` after `shutdown` then `exit`, and status `1` when `exit`
arrives without a prior shutdown, following the LSP lifecycle contract. EOF after
a normal shutdown should also end cleanly. Logs go to stderr; stdout is reserved
exclusively for framed protocol messages.

### Text Synchronization

Advertise:

```text
openClose = true
change = Full
save = false
```

Handle:

- `textDocument/didOpen`: validate `.res`/`.resi`, store the supplied text and
  version, lint it immediately, then publish diagnostics with that version.
- `textDocument/didChange`: accept the full replacement for a newer document
  version, replace the immutable document value, lint it, and publish diagnostics
  for that version.
- `textDocument/didClose`: remove the document and publish an empty diagnostic
  array so the client clears stale findings.

Do not reread open documents from disk. `didSave` is unnecessary for source-local
linting and should not be requested initially. Ignore stale or duplicate change
versions and log them; never publish diagnostics for an older version after a
newer version has been accepted.

### Diagnostics

Map each current diagnostic to:

- `range`: zero-based, end-exclusive LSP range in the negotiated encoding;
- `severity`: `Error` for the current rule policy;
- `code`: the rule id, such as `no-console` or `throws-analysis`;
- `source`: `rescript-lint`;
- `message`: the existing diagnostic message.

Publish parse and analysis failures as editor diagnostics instead of treating
them as process failures. `Lint_error.Parse_errors` and
`Lint_error.Analysis_errors` already carry structured diagnostics; expose a pure
helper that returns those diagnostics without parsing rendered CLI strings.
Open-buffer linting should not produce read or write errors. A boundary failure
that cannot be attached accurately to source becomes a stderr or
`window/logMessage` entry, not a fake successful lint result.

Keep CLI outcome semantics unchanged. The LSP adapter consumes the same typed
result but maps it to a protocol response rather than exit codes.

## Position Conversion

This is the highest-risk correctness boundary. Current diagnostics use one-based
lines, UTF-8 byte columns, absolute zero-based byte offsets, and exclusive range
ends. LSP positions are zero-based and use a negotiated number of code units.

Build an immutable line index from the exact open-buffer text. Convert diagnostic
absolute byte offsets through that index:

1. Find the containing line start without scanning the whole document for every
   diagnostic.
2. Validate and clamp only at a documented recovery boundary; ordinary valid
   ranges must round-trip exactly.
3. For `utf-8`, count bytes from the line start.
4. For `utf-16`, decode Unicode scalars and count two code units for characters
   outside the BMP.
5. Exclude `\n` and the `\r` in CRLF endings from line character counts.

Negotiate from `general.positionEncodings`: choose `utf-8` when offered, otherwise
choose `utf-16`. When the client omits the capability, use `utf-16`, which is the
protocol default.

Table-driven tests must cover ASCII, `e` with an acute accent, emoji, combining
marks, mixed Unicode on earlier lines, empty lines, EOF, CRLF, and ranges that end
at the next line. Add round-trip properties for every byte boundary that begins a
valid Unicode scalar.

## Responsiveness and Ordering

Start without a timer or background domain. Measure full parse-and-lint latency
on representative clean, invalid, JSX-heavy, hooks-heavy, and throws-heavy files.
Record median and p95 results for approximately 500, 2,000, and 5,000 lines.

Initial targets, subject to measurement:

- startup to initialize response below 150 ms on supported release machines;
- p95 open/change diagnostics below 50 ms for a representative 5,000-line file;
- memory proportional to total open-buffer text, with no retained closed buffers;
- no stale diagnostic publication under rapid sequential version updates.

If synchronous p95 exceeds the target, add one bounded latest-value worker rather
than unbounded jobs. Each job carries `(uri, version, text)`. Publish only when the
document store still contains that exact version. Cancellation may discard work;
it must never discard the latest accepted version. Debouncing is an optimization,
not a correctness mechanism.

## Safe Fixes: Second Release

After diagnostics are stable in Zed, expose current `Text_edit` values through
`textDocument/codeAction` as `quickfix` actions.

- Advertise code actions only when the client supports them.
- Recompute or validate fixes against the exact current document version.
- Return a versioned `TextDocumentEdit`; never write the file from the server.
- Convert edit byte offsets with the same position module used for diagnostics.
- Combine the edits for one diagnostic into one preferred action.
- Use a concise title such as `Apply blank-lines fix`.
- Return no action if the diagnostic cannot be matched to the current version.
- Do not expose `--fix` or `Source.write` through an LSP command.

Test overlapping edits, multiple diagnostics, Unicode before an edit, stale
diagnostics in a code-action request, and client application of the returned edit.
Formatting remains outside the server capability set.

## Project Awareness: Later Release

Source-local rules require no workspace scan. Project-wide throws metadata and
configuration will eventually need project contexts:

- retain `rootUri` and `workspaceFolders` from initialization;
- discover the nearest `rescript.json` for an open document;
- keep independent indexes for multi-root workspaces;
- give open buffers precedence over disk content;
- invalidate declarations affected by a changed or closed document;
- use `workspace/didChangeWatchedFiles` only for closed files, configuration, or
  compiler metadata that the editor does not synchronize as open text;
- report missing or stale semantic inputs explicitly.

Do not block the first LSP release on directory discovery or project-wide throws.
Design the document store so a later project index can subscribe to document
changes without changing transport code.

## Zed Integration

The existing `rescript-lang/rescript-zed` extension already owns ReScript file
recognition, the Tree-sitter grammar, queries, and the main
`@rescript/language-server`. Extend it upstream instead of adding a second ReScript
language extension.

Implementation steps:

1. Publish or otherwise provide installable prerelease binaries containing
   `rescript-lint lsp --stdio` for the supported platform matrix.
2. Add a second language-server entry for `rescript-lint` targeting the existing
   `ReScript` language.
3. Extend the Rust adapter to dispatch on the language-server id.
4. Honor Zed's user-provided binary override first, then search the worktree/PATH
   where the API permits it, then install `@jvlk/rescript-lint` through Zed's npm
   helper.
5. Launch the package's Node wrapper with `lsp --stdio`; the wrapper continues to
   select and supervise the native platform package.
6. Add an independent linter version setting so pinning it does not change the
   version of `@rescript/language-server`.
7. Return a clear unsupported-platform error outside Linux glibc x64/ARM64.
   macOS and Windows are deferred from the current alpha.
8. Exercise the adapter as a locally installed Zed dev extension, then open an
   upstream PR to `rescript-lang/rescript-zed`.

Zed publishing rules do not allow bundling the language server in the extension;
the adapter must find or download it. Keep the extension thin and leave all lint
behavior in this repository.

Manual Zed acceptance matrix:

- opening clean and failing `.res` and `.resi` files;
- diagnostics before save and after an unsaved edit;
- diagnostic clearing after a fix and after close;
- syntax errors while typing and recovery afterward;
- non-ASCII diagnostic positions;
- simultaneous operation with `rescript-language-server`;
- a project with no `node_modules`;
- configured local binary override;
- automatic npm installation on every supported OS/architecture;
- upgrade and pinned-version behavior;
- clear logs for install failure, unsupported platform, crash, and protocol error.

## VS Code Follow-Up

After the server protocol and packaging are proven in Zed, create a thin VS Code
client using the same executable and document selectors for `.res` and `.resi`.
The client should contain no lint rules, parsing, range conversion, or fix logic.

Decide with the ReScript maintainers whether this belongs in the official
`rescript-vscode` extension or in a focused `rescript-lint` extension. A focused
extension is acceptable because VS Code can attach another diagnostic language
client without redefining ReScript syntax support. In either case:

- launch `rescript-lint lsp --stdio` through the npm package;
- expose binary path and version settings comparable to Zed;
- use the same protocol transcript suite for server compatibility;
- add extension-host tests for activation, diagnostics, restart, and disposal;
- avoid implementing editor behavior that should be a standard LSP capability.

## Test Strategy

### Pure Unit Tests

- lifecycle state transitions and invalid ordering;
- immutable document open/change/close behavior;
- stale and duplicate version handling;
- URI and source-kind conversion;
- UTF-8 and UTF-16 position conversion;
- lint result to diagnostic conversion;
- code-action edit conversion when that phase lands.

### Protocol Transcript Tests

Drive the real executable with framed JSON-RPC and assert complete frames, not
substring output:

- initialize capability negotiation with UTF-8, UTF-16, and omitted encodings;
- initialize/initialized/shutdown/exit lifecycle;
- clean open publishes an empty array;
- lint finding, syntax error, and analysis error publication;
- full changes replace text and carry the new version;
- rapid versions never publish an older result last;
- close clears diagnostics;
- unknown request returns method-not-found;
- malformed JSON, missing/invalid/oversized `Content-Length`, partial body, and
  unexpected EOF behavior;
- no unframed stdout under any success or failure path.

### Integration and Release Tests

- run the server under a small reference LSP client in CI;
- run the Zed dev-extension acceptance matrix before the upstream PR;
- retain the existing build, formatting, unit, cram, npm package, source-bundle,
  rebuild, and coverage gates;
- add the server dependency graph to distribution/license validation;
- verify the packaged Node launcher preserves stdio and forwards termination to
  the native server.

## Delivery Slices

### Slice 0: Protocol and Dependency Spike

Deliver a throwaway initialize/open/publish/shutdown loop and a short decision
record comparing `lsp`/`jsonrpc` with `linol`. Confirm Zed interoperability and
obtain production-dependency approval.

Exit: Zed receives one hard-coded diagnostic from the development binary, the
process shuts down correctly, and the dependency choice is recorded.

### Slice 1: Core Editor Boundaries

Implement position encoding, URI handling, open-document values, and structured
extraction of lint/parse/analysis diagnostics. These modules are pure and tested;
the CLI remains behaviorally unchanged.

Exit: in-memory Unicode sources convert to exact UTF-8 and UTF-16 LSP diagnostics
without a running server.

### Slice 2: Minimum Diagnostic Server

Implement the lifecycle, full synchronization, version checks, push diagnostics,
stdio framing, logging discipline, command parsing, and transcript tests.

Exit: the packaged binary provides live, unsaved diagnostics in a reference LSP
client and passes all repository gates.

### Slice 3: Zed Development Integration

The adapter and installation/version logic are implemented on a local
`rescript-zed` feature branch. Install that checkout as a dev extension and run
the manual acceptance matrix.

Exit: a Zed dev extension runs both ReScript servers without duplicate language
definitions, stale diagnostics, or a project-local Node installation.

### Slice 4: Prerelease and Upstream Zed PR

Publish signed/checksummed prerelease artifacts through the existing package
pipeline, document troubleshooting, and submit the `rescript-zed` change.

Exit: a clean supported machine can install the dev/upstream extension, acquire
the correct native package, and show diagnostics.

### Slice 5: Quick Fixes

Add versioned `quickfix` code actions for existing safe edits and exercise them in
Zed.

Exit: Zed applies `blank-lines` edits to the unsaved buffer without direct file IO
and rejects stale actions.

### Slice 6: Project Context

Add configuration, project roots, declaration metadata, closed-file invalidation,
and multi-root behavior as required by project-wide rules.

Exit: project-aware diagnostics remain correct across interface/implementation
changes, dependency metadata changes, and multiple workspace roots.

### Slice 7: VS Code Client

Build the thin client, reuse the same server/package, and publish only after its
extension-host tests and the server compatibility suite pass.

Exit: Zed and VS Code produce equivalent diagnostics and fixes from the same
server release.

## Release Criteria

The first LSP release is ready when:

- no protocol logs or diagnostics leak as unframed stdout;
- lifecycle and framing failures are deterministic and tested;
- clean, lint, parse, and analysis results appear correctly for unsaved buffers;
- UTF-8 and UTF-16 clients receive exact ranges;
- stale versions cannot overwrite current diagnostics;
- close clears diagnostics;
- CLI lint, fix, and watch contracts remain unchanged;
- every affected file and the project remain above the existing coverage gate;
- supported native packages pass install and stdio smoke tests;
- the Zed acceptance matrix passes alongside the existing ReScript server;
- dependency licenses and corresponding source are present in native packages;
- limitations and troubleshooting steps are documented before publication.

## Explicit Non-Goals for the First Release

- replacing `@rescript/language-server`;
- completion, hover, navigation, rename, semantic tokens, or formatting;
- compiler/build orchestration;
- CLI watch integration;
- recursive workspace linting;
- project-wide throws guarantees;
- background parallel analysis before benchmarks justify it;
- editor-specific rule implementations;
- Windows support before a Windows native package passes the release gates.

## References

- [Language Server Protocol 3.18 specification](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/)
- [OCaml `lsp` package](https://opam.ocaml.org/packages/lsp/)
- [OCaml `jsonrpc` and `lsp` implementation](https://github.com/ocaml/ocaml-lsp)
- [`linol` package](https://opam.ocaml.org/packages/linol/)
- [Zed language extension documentation](https://zed.dev/docs/extensions/languages)
- [Zed extension publishing prerequisites](https://zed.dev/docs/extensions/publishing/prerequisites)
- [Existing ReScript Zed extension](https://github.com/rescript-lang/rescript-zed)
- [ReScript Tree-sitter grammar](https://github.com/rescript-lang/tree-sitter-rescript)
