# Effective Configuration and Restrictions

```sh
rescript-lint --inspect-config src/Main.res --config rescript-lint.json
rescript-lint --config rescript-lint.json --disable-rule no-console --inspect-config src/Main.res --format json
```

Inspection uses the same command parsing and `Rule_config.for_file` resolution
as lint, fix, watch and LSP. It accepts exactly one filename, which need not
exist. It does not discover project files, parse source, load artifacts or run
analysis. Success exits 0; malformed options/configuration exit 2. Fix, watch,
LSP and extra positional files cannot be combined with inspection.

Base settings follow command argument order, including repeated `--config` and
rule flags. Matching per-file overrides apply afterward in declaration order.
This preserves existing behavior: a file override wins over a CLI base setting.
An explicitly supplied override array replaces the previous array; `[]` clears it.

The deterministic version-1 JSON object contains `filename`, `analysis: "not-run"`,
`rules`, `options`, and `optionOrigins`. Every registered rule has its final
`enabled` state, `origin`, and `requirements`. Origins identify defaults, the
supplied config filename, CLI flag, or config filename plus zero-based override
index. Human output carries the same information. Requirements distinguish
missing/configured adapters and project settings; compiler artifacts and
dependency declarations are explicitly `not-checked`. Configured is not a claim
that analysis will succeed on a particular file.

## Schema

The npm package ships `config.schema.json`, generated from `Config_schema` and
the rule registry. Regenerate it with:

```sh
opam exec -- dune exec scripts/generate_config_schema.exe > npm/config.schema.json
```

The test suite checks the shipped schema against the generator and rule registry.
Set `$schema` to the installed schema path for editor completion. The runtime
accepts this property only as a string and never fetches it. Unknown properties,
unknown rules, nonboolean activation, invalid adapters/limits, and duplicate
object keys remain errors. Schema validation cannot detect duplicate JSON object
keys, case-insensitive duplicate warning terms, normalized duplicate selectors,
or integer-token spelling (for example, the decoder rejects `1.0` for limits).
The runtime remains authoritative for these constraints.

## Restrictions

Enable `no-restricted-modules` and supply `restrictedModules`, `restrictions`,
or both. An enabled rule with no policy fails explicitly.

```json
{
  "$schema": "./node_modules/@jvlk/rescript-lint/config.schema.json",
  "rules": {"no-restricted-modules": true},
  "restrictedModules": ["Internal"],
  "restrictions": [
    {"kind": "module", "path": "Database", "message": "Use the service API."},
    {"kind": "value", "path": "Database.query", "message": "Use UserService.find."},
    {"kind": "type", "path": "Database.row", "message": "Use User.t.", "url": "https://example.com/architecture"}
  ]
}
```

Module entries match the exact module or descendants after a dot boundary,
across all three reference kinds. Value and type entries match an exact
canonical path in their respective namespace. Exact value/type matches win over
module prefixes; otherwise the longest prefix wins. Equal specificity uses the
first configured entry. Legacy prefixes follow explicit entries for ties.
One finding is emitted per matching reference, carrying the resolved symbol and
optional guidance. Messages supplement the violation, never replace the rule ID.
URLs require a message and an HTTP(S) prefix. No policy URL is fetched.

Type coverage includes annotations, type definitions, record/variant payloads,
externals, patterns, module signatures and `.resi` declarations. Known lexical
module aliases and opens/includes preserve identities. Type and module shadows
are respected. Project signatures retain `.resi` precedence. Type aliases are
references at their declaration; subsequent uses have their own declaration
identity, not the underlying type's identity.

This remains bounded source analysis. Unknown exports, unresolved named module
types/functor results, constructor/record-field references, declaration-origin
restrictions and arbitrary dependency provenance are not covered. Existing
adapter, parse, project and throws failures remain errors; inspection does not
discharge them. No new production dependency is required.
