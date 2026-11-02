# `require-interface`

Requires each applicable implementation module in the configured source set to have a matching `.resi` interface.

- Category: `restriction`
- Enabled by default: No
- Autofix: No

An explicit interface documents and constrains the module's public contract.

## Examples

### Incorrect

```text
Project layout:
src/Token.res
```

```rescript
// src/Token.res
type t = string
let make = text => text
```

### Correct

```text
Project layout:
src/Token.res
src/Token.resi
```

```rescript
// src/Token.res
type t = string
let make = text => text
```

```rescript
// src/Token.resi
type t
let make: string => t
```

## Configuration

```json
{
  "root": ".",
  "rules": {
    "require-interface": true
  }
}
```

The project's `rescript.json` must discover `src`. Set the rule to `false`
to disable it.

```sh
npx rescript-lint --config rescript-lint.json
```

## Limitations

Matching interfaces must be present in the configured source set. Interface files themselves are exempt; this rule does not generate interfaces.
