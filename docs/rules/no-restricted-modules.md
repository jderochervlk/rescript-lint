# `no-restricted-modules`

Forbids configured module, type, or value references to enforce project dependency boundaries.

- Category: `restriction`
- Enabled by default: No
- Autofix: No

This rule needs a nonempty restriction policy. The legacy `restrictedModules`
option accepts module prefixes; `restrictions` also supports exact value/type
policies and optional guidance.

## Examples

Assume `rescript.json` discovers these files under `src`:

```rescript
// src/Database.res
module User = {
  let find = id => id
}
```

```rescript
// src/UserService.res
let find = id => id
```

### Incorrect

```rescript
// src/Profile.res
let load = id => Database.User.find(id)
```

### Correct

```rescript
// src/Profile.res
let load = id => UserService.find(id)
```

## Configuration

```json
{
  "root": ".",
  "restrictedModules": ["Database"],
  "rules": {
    "no-restricted-modules": true
  }
}
```

Supply a nonempty `restrictedModules` list, a nonempty `restrictions` list, or
both. The latter supports exact value/type policies and optional guidance;
see [configuration](../configuration/CONFIGURATION.md#restrictions).
Set the rule to `false` to disable it.
Run `npx rescript-lint --config rescript-lint.json`.
The project root supplies the cross-file declarations used in these examples.

## Limitations

The rule checks resolved canonical module/type/value references and configured policies. It does not perform workspace/package dependency resolution.

See [project rules](EXTENDED_RULES.md#project-rules) and [audited examples](RULE_EXAMPLES.md#no-restricted-modules).
