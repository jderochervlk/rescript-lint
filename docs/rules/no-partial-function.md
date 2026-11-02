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

This checks known partial/throwing runtime APIs. Invalid-value unsafe APIs are covered separately by `no-unsafe`.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#no-partial-function).
