# Distribution Licenses and Corresponding Source

Original linter and launcher code is Copyright (c) 2026 Josh Vlk, under the MIT
License in `LICENSE`. This does not relicense third-party code. The native
executable uses the libraries below, including LGPL-covered portions whose
use and redistribution are governed by their respective licenses.

The JavaScript launcher package declares `MIT`. Native packages declare
`SEE LICENSE IN DISTRIBUTION.md` and include a `third-party/` directory with
license texts, notices, complete upstream source archives, application source,
and rebuild instructions. The launcher has no embedded native dependencies;
the bundle is in its installed platform-specific optional dependency.

## Included Libraries

| Library / linked portions | Reviewed version | Applicable notices |
| --- | --- | --- |
| ReScript compiler `ext`, `ml`, `syntax` and C hash stubs | 12.3.1, `679406560d169f1124653ab50795d5077570f078` | MIT syntax; LGPL-3.0-or-later compiler files, some with explicit additional permissions; inherited OCaml LGPL-2.1/linking-exception notices |
| Flow parser, collections, sedlexing | 0.267.0, `9ea4062c0b7e037415c4413a7634c459ebd5c31b` | MIT parser/sedlex; inherited OCaml collection code under LGPL-2.1 with linking exception |
| OCaml LSP protocol types and JSON-RPC framing | `lsp` 1.27.0, `jsonrpc` 1.27.0 | ISC, OCaml Labs and contributors |
| Yojson | 3.0.0 | BSD-3-Clause, Martin Jambon and contributors |
| PPX Yojson conversion runtime | v0.17.0 | MIT, Jane Street |
| Uutf Unicode codec | 1.0.4 | ISC, Daniel Bünzli |
| OCaml runtime, standard library, Unix | 5.5.0 | LGPL-2.1 with OCaml linking exception; additional per-file runtime notices |
| Base, internal hash types/C stubs, shadow stdlib | v0.17.3 | MIT, Jane Street and per-file notices |
| Sexplib0 | v0.17.0 | MIT, Jane Street |
| OCaml intrinsics kernel and C stubs | v0.17.2 | MIT, Jane Street |
| WTF-8 | 1.0.2 | MIT, Facebook |
| PPX deriving runtime | 6.2.0 | MIT, whitequark |

The review used the release executable's Dune link rule and executable symbols,
not just the list of installed development tools. The inventory conservatively
includes entire link-input packages, even where dead-code elimination omits
modules. The complete archives retain original per-file copyright notices and
additional third-party license terms; not every file in an archive is linked
into the executable. Extracted notices retain their upstream paths under
`third-party/licenses/<library>/`.

## Source and Relinking

We use a source-accompanying distribution approach for the LGPL portions:
LGPL v3 section 4(d)(0), and LGPL v2.1 section 6(a), rather than relying on a
blanket linking exception. The full applicable GPL/LGPL texts are included.
Our original application source remains MIT. Library sources retain upstream
licenses; any additional linking permissions remain intact.

Every native package includes:

- `third-party/application.tar.gz`: the application sources, MIT license,
  Dune/Opam build definitions, and parser adapters used to build it.
- `third-party/sources/`: complete, checksum-verified upstream archives for
  every library package in the table, including the OCaml runtime sources.
- `third-party/licenses/`: verbatim upstream license/notice files, including
  ReScript's GPL v3/LGPL v3 texts and OCaml/Flow's LGPL v2.1 exception texts.
- `third-party/dependencies.json`: versions, source origins, revisions, and hashes.
- `third-party/bundle.json`: application-source, binary, and bundle-file hashes.
- `third-party/REBUILD.md`: extraction, dependency pinning, rebuilding, relinking,
  and replacement instructions.

You may modify the LGPL-covered libraries and rebuild/relink the application;
we impose no restriction on reverse engineering for debugging those changes.
No signing keys or activation service are required to run a modified binary.
Source is supplied alongside the executable, not only via upstream URLs or a
written offer. Ordinary system libraries and separately installed build tools
are not bundled binaries; see `REBUILD.md` for prerequisites.

## Build and Packaging Controls

`npm run prepare:licenses` verifies installed dependency versions, the pinned
Flow revision, and a clean ReScript checkout at the recorded revision. Locally
pinned replacements for released dependencies are rejected. It fetches source
archives only at build time, checks their pinned hashes before extraction,
and caches them under ignored `dist/compliance/downloads/`. Opam registry hashes
were used for released dependencies; the two Git source archives are pinned by
commit and reviewed SHA-256 digest in `scripts/npm/dependencies.json`.

`npm run pack:native` refuses missing or changed bundle contents, source files,
rebuild instructions, dependency metadata, or a binary changed since preparation.
The install smoke test verifies that the bundle survives npm packing. The rebuild
test extracts the application and ReScript sources into a new directory, modifies
a library initializer, rebuilds, and verifies that the new executable runs it.
It uses the existing Opam toolchain/dependency installation; it is not an offline
bootstrap test of every dependency or a bit-for-bit reproducibility claim.

Dependency upgrades or new linked libraries require updating this inventory,
archive checksums, and notices. Adding a new OS or statically bundled system
library requires a fresh runtime/dependency audit. This document records the
project's engineering compliance approach, not a legal opinion or warranty.
Publication remains separately guarded pending release approval and platform CI.

## Primary References

- [Pinned ReScript license summary](https://github.com/rescript-lang/rescript/blob/679406560d169f1124653ab50795d5077570f078/LICENSE)
- [LGPL v3 text shipped by ReScript](https://github.com/rescript-lang/rescript/blob/679406560d169f1124653ab50795d5077570f078/COPYING.LESSER)
- [OCaml runtime license and linking exception](https://github.com/ocaml/ocaml/blob/5.5.0/LICENSE)
- [Flow collection license and linking exception](https://github.com/rescript-lang/flow/blob/9ea4062c0b7e037415c4413a7634c459ebd5c31b/src/hack_forked/utils/collections/third-party/LICENSE)
