# Distribution Status

These are private development packages, not an npm release. Do not publish or
redistribute the native artifacts until the distribution-license review is complete.

The project's original code is Copyright (c) 2026 Josh Vlk and licensed under
the MIT License in `LICENSE`. This does not relicense third-party sources or
claim that the bundled executable is MIT-only. Upstream code retains its own
licenses and notices.

The main npm launcher package declares `MIT`. Native package metadata points
to this document with `SEE LICENSE IN DISTRIBUTION.md` because those packages
also contain linked dependencies. Their license inventory is not yet complete.
`private: true` remains the publication guard on both package types.

The binary links sources from ReScript v12.3.1, commit
`679406560d169f1124653ab50795d5077570f078`, and its Flow parser fork, commit
`9ea4062c0b7e037415c4413a7634c459ebd5c31b`.

- ReScript: https://github.com/rescript-lang/rescript/tree/679406560d169f1124653ab50795d5077570f078
- Flow: https://github.com/rescript-lang/flow/tree/9ea4062c0b7e037415c4413a7634c459ebd5c31b

ReScript syntax sources carry MIT notices. Other linked compiler sources include
LGPL and inherited OCaml notices/linking exceptions. Flow carries MIT notices.
The OCaml runtime and transitive build dependencies also need review. This file
is a review checklist and source attribution, not a replacement for required
license texts, notices, source availability, or other redistribution obligations.

Before release, inventory the linked sources,
include the applicable license texts and notices in each distributable package,
and satisfy any additional obligations. See `docs/DEPENDENCIES.md` in the source
repository for the build boundary and pinned dependencies.

## Initial link inventory

The local Linux x64 release build was inspected on 2026-09-20 using
`opam exec -- dune rules _build/default/bin/main.exe`, installed package metadata,
and executable symbols. Its link inputs include:

| Dependency | Local version | License review inputs |
| --- | --- | --- |
| ReScript `ext`, `ml`, `syntax` | Pinned commit above | Root license texts plus per-file notices and exceptions |
| Flow parser, private collections and sedlexing | Pinned commit above | Root MIT license and included third-party notices |
| OCaml standard library, Unix, runtime | 5.5.0 | `_opam/doc/ocaml/LICENSE`, including linking exception; runtime notices |
| Base, internal hash types, shadow stdlib | v0.17.3 | `_opam/doc/base/LICENSE.md` (MIT) and included source notices |
| Sexplib0 | v0.17.0 | `_opam/doc/sexplib0/LICENSE.md` (MIT) |
| OCaml intrinsics kernel | v0.17.2 | `_opam/doc/ocaml_intrinsics_kernel/LICENSE.md` (MIT) and C stubs |
| WTF-8 | 1.0.2 | `_opam/doc/wtf8/LICENSE` (MIT) |
| PPX deriving runtime | 6.2.0 | `_opam/doc/ppx_deriving/LICENSE.txt` (MIT) |

Link inputs are a conservative starting inventory, not proof that every module
in every archive is retained. Conversely, an absent OCaml entry symbol does not
exclude linked C stubs or inlined code. Development-only tools are not thereby
part of the distributed executable. Repeat the inventory on every release target:
transitive versions are not fully locked and can differ between Opam solves.

Some inherited ReScript compiler files refer to an OCaml linking exception in
`LICENSE`, while ReScript's current root license file is only a directory-level
summary. Trace the applicable historical text before treating those references
as a blanket exception. Other files explicitly grant additional LGPL permissions.
Preserve those notices together with the full applicable license texts.

The local paths above locate review material; those files are **not yet included
in npm tarballs**. This inventory does not discharge source or notice obligations.
