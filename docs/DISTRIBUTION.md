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
