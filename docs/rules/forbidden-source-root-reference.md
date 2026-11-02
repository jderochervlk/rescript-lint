# `forbidden-source-root-reference`

Disallow value and type references to declarations owned by configured source roots.

- Category: `restriction`
- Enabled by default: No
- Autofix: No

Configure `forbiddenSourceRoots` for the project. The rule follows declaration
provenance, rather than relying only on a module's spelling.

## Examples

Assume the project's `rescript.json` discovers `src` recursively, including
`src/generated`, `src/api`, and `src/app`. The two API files contain:

```rescript
// src/generated/GeneratedApi.res
let value = 42
```

```rescript
// src/api/PublicApi.res
let value = 42
```

### Incorrect

```rescript
// src/app/Feature.res
let generatedValue = GeneratedApi.value
```

### Correct

```rescript
// src/app/Feature.res
let publicValue = PublicApi.value
```

## Configuration

```json
{
  "root": ".",
  "forbiddenSourceRoots": ["src/generated"],
  "rules": {
    "forbidden-source-root-reference": true
  }
}
```

Requires `root`, discovered project declarations, and a nonempty
`forbiddenSourceRoots` list. Optional `sourceRootDependencies` lists actual
dependency-package directories to load; omit it when not needed. Paths are
anchored to the configuration file. Set the rule to `false` to disable it.

```sh
npx rescript-lint --config rescript-lint.json
```

## Limitations

Checks value and type references, not module references, constructors, or
record-field labels. Consumers inside the first matching forbidden root are
exempt, so configured root order matters when roots overlap. Public `.resi`
declarations own cross-file provenance when an interface exists.

It does not infer intended architectural boundaries or traverse every workspace
dependency automatically. Required unresolved provenance fails analysis.

See [project configuration](../configuration/CONFIGURATION.md#source-root-restrictions)
and the [declaration-provenance contract](../analysis/DECLARATION_PROVENANCE.md).
