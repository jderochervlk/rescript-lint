# `no-catch-all-exception`

Disallow unguarded catch-all exception patterns that swallow every exception.

- Category: `restriction`
- Enabled by default: No
- Autofix: No

Handle specific expected failures instead of hiding unexpected exceptions
behind a wildcard or variable catch-all.

## Examples

### Incorrect

```rescript
let readOptional = read => try {
  Some(read())
} catch {
| _ => None
}
```

### Correct

```rescript
let readOptional = read => try {
  Some(read())
} catch {
| Not_found => None
}
```

## Configuration

```json
{
  "rules": {
    "no-catch-all-exception": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it.

## Limitations

Covers unguarded wildcard/bound-variable patterns in try handlers and switch
exception arms, with a supported immediate-rethrow exemption. Ordinary
switch wildcards are not exception handlers. A rethrow can still receive
[`no-useless-catch`](no-useless-catch.md); neither rule proves recovery quality.

See the [exception boundaries](SYNTAX_RULES.md#exception-and-debugger-boundaries).
