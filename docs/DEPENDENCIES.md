# Parser Dependency

## Pinned source

The Git submodule at `vendor/rescript` pins official ReScript **v12.3.1**, commit `679406560d169f1124653ab50795d5077570f078`. This is the only currently tested syntax version; it is not a claim of compatibility with every ReScript release.

The checkout is unchanged. Initialize it with `git submodule update --init`. The parent repository's Git link records the commit; no moving branch is followed.

## Build boundary

The compiler's `syntax` library is private to its Dune project. `vendor/parser/` provides build-only adapters for its `syntax`, `ml`, and `ext` libraries. Dune copies the selected upstream source directories into `_build/` and builds them in our project scope. The adapter preserves upstream preprocessing, generated modules, C stubs, and warning flags. It does not rewrite OCaml source or depend on an installed ReScript executable.

`vendor/rescript` is a Dune data-only directory, so upstream tests, tools, and executables do not enter our build. `vendor/parser` is vendored for Dune checks; our own library and CLI retain fatal warnings. Coverage instrumentation and thresholds apply to our `lib/` and `bin/`, not upstream code.

The `ml` library depends on ReScript's Flow parser fork. `rescript_linter.opam.template` pins `flow_parser.0.267.0` to commit `9ea4062c0b7e037415c4413a7634c459ebd5c31b`, matching the compiler release's own Opam template. Generated package metadata carries that pin. Cppo 1.8.0 is a build dependency. Opam installs Flow's transitive dependencies.

## API boundary

`lib/parser.ml` uses `Res_driver.parse_implementation_from_source` and `parse_interface_from_source` with `for_printer:true`, preserving surface syntax for linting. It does not use file APIs that can print and terminate the process. Parser diagnostics become typed errors; invalid recovered trees never reach a rule.

Rules currently consume the compiler's AST directly. Diagnostics and CLI behavior are compiler-independent. `lib/source_range.ml` translates the parser's mixed byte-offset/UTF-16-column positions into our UTF-8 byte ranges using the original source.

## Licenses

Upstream's license texts and per-file notices remain in the submodule. ReScript's syntax directory carries MIT licensing; other linked compiler sources have LGPL and inherited OCaml notices/linking exceptions. The Flow parser fork carries MIT licensing and its own notices. The resulting dependency graph must not be described as MIT-only. Review these notices before distributing binaries, preserve required attribution, and decide this project's license separately.

## Upgrades

1. Select a release, review its source/license changes, and update the submodule Git link.
2. Compare upstream `compiler/{ext,ml,syntax/src}/dune` with the adapter stanzas and the compiler's parent preprocessing environment.
3. Check the release's Flow pin and update `dune-project` and the Opam template if needed. Regenerate the Opam file through Dune.
4. Compare console, unchecked-cast, and unsafe API declarations against the rule inventories. The unsafe-rule test independently checks selected exported declarations in the pinned runtime; review its module list and aliases when upgrading.
5. Run `make check`, `make coverage`, and `opam exec -- dune build --profile release @install`. Review parsing, shadowing, invalid source, and Unicode range regressions before declaring compatibility.
