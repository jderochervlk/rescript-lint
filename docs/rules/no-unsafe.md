# `no-unsafe`

Disallow known unsafe standard-library APIs, regardless of their arguments.

- Category: `correctness`
- Enabled by default: Yes
- Autofix: No

Prefer checked APIs and explicit pattern matching. This is an API policy:
even `Option.getUnsafe(Some(value))` is a violation, and catching exceptions does
not grant an exemption.

## Examples

### Incorrect

```rescript
let displayName = (name: option<string>) => Option.getUnsafe(name)
```

### Correct

```rescript
let displayName = (name: option<string>) => switch name {
| Some(value) => value
| None => "Anonymous"
}
```

## Configuration

```json
{
  "rules": {
    "no-unsafe": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it.

## Limitations

Uses an explicit ReScript 12.3.1 inventory across the modern standard library,
legacy `Js`, typed arrays, and `Belt`. Supported aliases and opens retain API
identity; an unrelated function whose name contains `unsafe` is not automatically
banned. There is no configuration option for adding arbitrary APIs.

`Option.getOrThrow` belongs to the separate throwing-API/exception policies.
A nonfinding is not proof of safety. See the
[unsafe API inventory](UNSAFE_APIS.md) and [full contract](RULES.md#no-unsafe).
