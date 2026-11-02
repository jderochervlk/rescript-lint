# `no-float-equality`

Discourages equality comparisons on known floating-point values, where rounding can make exact equality surprising.

- Category: `pedantic`
- Enabled by default: No
- Autofix: No

Compare the difference with a domain-appropriate tolerance when approximate equality is intended.

## Examples

### Incorrect

```rescript
let closeEnough = (measured: float, expected: float) => measured == expected
```

### Correct

```rescript
let closeEnough = (~measured, ~expected, ~tolerance) =>
  Math.abs(measured -. expected) <= tolerance
```

## Configuration

```json
{
  "rules": {
    "no-float-equality": true
  }
}
```

Set the value to `false` to disable this rule.
Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Known float equality is checked; literal sentinel comparisons have specific exclusions. Select a tolerance based on the domain rather than treating one universal epsilon as correct.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#no-float-equality).
