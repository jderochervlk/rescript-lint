# Declaration Provenance and Source-Root Restrictions

`forbidden-source-root-reference` is an opt-in project rule for preventing value
and type references to declarations owned by selected source directories.

```json
{
  "root": ".",
  "rules": {"forbidden-source-root-reference": true},
  "forbiddenSourceRoots": ["src/internal", "src/generated"],
  "sourceRootDependencies": ["node_modules/example-package"]
}
```

All paths are relative to the configuration file. `root` and at least one
`forbiddenSourceRoots` entry are required while the rule is enabled.
`sourceRootDependencies` is optional and contains explicit ReScript package roots,
not package names. Each dependency must have a supported `rescript.json` with a
name and explicit source directories. Nothing is resolved implicitly through
`node_modules`.

## Root Matching

Configured roots are resolved with `realpath` when analysis runs. Missing,
unreadable, non-directory, and duplicate canonical roots fail with
`source-root-analysis`; they never produce a clean result. Declaration and
consumer filenames are canonicalized the same way. A symlink configured as a
root therefore protects its target, and a consumer reached through another
symlink to that target receives the same-root exemption.

Roots match only at directory boundaries. `src/internal` does not match
`src/internal-old`. Configuration order is significant: the first root containing
the declaration controls the result. A consumer is exempt only when it is inside
that matched root. Being inside a different configured root is not an exemption.

## Declaration Ownership

The adapter derives origins from parsed source declarations rather than module
spelling or compiler artifacts:

- A public `.resi` value or type owns cross-file references to that declaration.
  A matching `.res` implementation does not leak hidden declarations or replace
  the interface origin.
- Without a `.resi`, the exported `.res` declaration owns the reference.
- Value aliases preserve the declaration origin they resolve to, including across
  project files. Module aliases, opens, inline includes and module re-exports also
  preserve origins.
- A type alias owns subsequent references to the alias. The aliased type use at
  the declaration is checked separately. This matches the existing type-identity
  contract used by `no-restricted-modules`.
- Local shadows own their local source file. Nested inline modules retain the
  origins of their declarations.
- Explicit dependency packages follow `.resi` precedence and their declared
  namespace. Package roots, names and public module roots must be unambiguous;
  declared dependency edges must be complete and acyclic.

Unknown named module types, functor results, unpacked modules and unknown opens
remain opaque. A value or type reference through one of those scopes produces
`source-root-analysis`; the adapter does not guess an identity. Unknown external
module roots that are not part of the configured project or dependency set remain
outside this source-only guarantee.

The first release checks `Pexp_ident` value references and `Ptyp_constr` type
references. Module references, constructors and record-field labels are not
source-root reference kinds. The rule emits no fixes.

## Operation

Project files use the immutable, content-checked parse cache. Dependency package
sources are rediscovered and parsed for active analysis; no compiler build or
artifact freshness contract is introduced. Watch mode observes project files,
dependency configurations and sources, configured roots, and the lint config.

CLI and LSP analysis give the current source buffer precedence over its disk
version. Other open LSP buffers are not yet a shared multi-buffer overlay, so a
consumer sees unsaved declarations from its own buffer but reads other providers
from disk. Changing or closing another provider buffer requires its saved file to
change before consumers are reanalyzed. This limitation is explicit and does not
permit guessed provenance.

## Verification

On 2026-10-03, `make check` and `make coverage` passed with 95.54% project
coverage and 100% coverage for `source_root_policy.ml`. The release `@install`
build, generated-schema parity, schema fixture validation, npm tests, bundled
source rebuild, native packing and installed-package smoke test also passed. The
pinned ReScript 12.3.1 catalog audit compiled and checked 236/236 examples with
no skips; Reanalyze supplied 229 real diagnostics. Live Zed validation and release
publication were not performed.
