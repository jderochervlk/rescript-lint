# `no-partial-function`

Flags recognized runtime functions that can throw or fail for particular inputs, encouraging total alternatives.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Prefer an option- or result-returning operation and handle its empty/error case explicitly.

## Examples

### Incorrect

```rescript
let first = items->List.headOrThrow
```

### Correct

```rescript
let first = items->List.head
```

## Configuration

```json
{
  "rules": {
    "no-partial-function": true
  }
}
```

Set the value to `false` to disable this rule. Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Checks the supported resolved throwing forms of list head/tail/index access and
option/result unwraps, such as `List.headExn` and `Option.getOrThrow`. This is a
small runtime inventory, not inference of every function that may throw.
Invalid-value unsafe APIs belong to the separate `no-unsafe` policy.
