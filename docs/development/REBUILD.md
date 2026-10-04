# Rebuilding the Native Linter

This package includes the application source and complete upstream source
archives, not just links or a promise to supply source later. Original license
notices remain in those archives. `licenses/` also contains extracted license
texts, notices, and credits. `dependencies.json` identifies the exact versions,
origins, and checksums. `bundle.json` records the packaged binary and file hashes.

Our application is MIT-licensed. ReScript compiler libraries and Flow's inherited
OCaml collections include LGPL-covered code; see `DISTRIBUTION.md` in the package
root. You may modify those libraries and rebuild/relink the linter. We impose no
restriction on reverse engineering for debugging those modifications. No signing
key, activation service, or proprietary installation tool is required.

## Application and ReScript

Start in this `third-party` directory. Use an empty workspace outside the installed
package. Commands below require a POSIX shell, tar (gzip/bzip2 support), a C toolchain,
and Opam 2.2+. Paths below use `work` as that workspace:

```sh
mkdir -p work/app/vendor/rescript work/deps
tar -xzf application.tar.gz -C work/app
tar -xzf sources/rescript.tar.gz --strip-components=1 -C work/app/vendor/rescript
```

The application archive includes `bin/`, `lib/`, Dune/Opam definitions, our MIT
license, and the `vendor/parser` build adapters. ReScript sources are unmodified;
the adapters copy and preprocess them in Dune's build directory. They do not
require the original Git checkout or submodule metadata.

## OCaml Dependencies

Extract every dependency archive into its own empty directory under `work/deps`,
stripping the single top-level archive directory, for example:

```sh
mkdir -p work/deps/flow_parser
tar -xzf sources/flow_parser.tar.gz --strip-components=1 -C work/deps/flow_parser
```

Repeat for `lsp`, `jsonrpc`, `yojson`, `ppx_yojson_conv_lib`, `uutf`, `base`,
`sexplib0`, `ocaml_intrinsics_kernel`, `wtf8`, `ppx_deriving`, and `ocaml`, using
the filenames in `dependencies.json`. The `lsp` and `jsonrpc` packages share the
`ocaml-lsp.tbz` source archive; extract it into both dependency directories. For
`.tbz` files use `tar -xjf`. The OCaml archive contains the runtime, standard
library, Unix library, compiler, and its own build/install instructions.

Create and initialize a local OCaml 5.5.0 Opam switch in `work/app` using the normal
Opam instructions. Build-only tools such as Dune 3.24.2, Cppo 1.8.0, PPX generators,
and the system compiler are obtained through Opam/system packages; their installed
tool binaries are not part of this npm package. Source archives for all linked
OCaml dependency packages are included here.

From `work/app`, pin each extracted library before installing build dependencies:

```sh
opam pin add --no-action base ../deps/base
opam pin add --no-action sexplib0 ../deps/sexplib0
opam pin add --no-action ocaml_intrinsics_kernel ../deps/ocaml_intrinsics_kernel
opam pin add --no-action wtf8 ../deps/wtf8
opam pin add --no-action ppx_deriving ../deps/ppx_deriving
opam pin add --no-action yojson ../deps/yojson
opam pin add --no-action ppx_yojson_conv_lib ../deps/ppx_yojson_conv_lib
opam pin add --no-action uutf ../deps/uutf
opam pin add --no-action jsonrpc ../deps/jsonrpc
opam pin add --no-action lsp ../deps/lsp
opam pin add --no-action flow_parser ../deps/flow_parser
opam install . --deps-only --ignore-pin-depends --yes
opam exec -- dune build --profile release @install
./_build/default/bin/main.exe --version
```

`--ignore-pin-depends` preserves the local Flow source pin instead of following the
remote development pin recorded in our Opam template. Match versions to
`dependencies.json`; the source archives remain usable without the original
upstream URLs. Opam may need network access for build-only tools. If modifying
the OCaml runtime itself, build/install the included compiler sources and use
that compiler for the switch; see its `INSTALL.adoc`.

Modify ReScript under `vendor/rescript/compiler/`, Flow or another library under
`work/deps`, or our code under `lib/` and `bin/`. After changing an Opam-pinned
library, reinstall that package, then rebuild the application. Interface-breaking
library changes may require corresponding application changes.

## Run or Replace

Run the rebuilt executable directly. To use it through the npm launcher, replace
`bin/rescript-lint` in the installed platform package with the rebuilt executable
and preserve executable permissions. That binary path is relative to the native
package root (the parent of this directory). The launcher checks package metadata,
not a binary signature, and does not prevent a modified executable from running.

These instructions produce a functional rebuild, not a promise of bit-identical
output across toolchains, build paths, operating systems, or compiler flags.
System shared libraries such as libc/libm on Linux and libSystem on macOS are
provided by the operating system and are not bundled here. Windows is deferred.
