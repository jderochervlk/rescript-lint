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

Checks equality on known computed floats, but exempts direct literal sentinel
comparisons such as `value == 0.0`. Intentional exact comparisons can be marked
on the expression, for example `@lint.exactFloat (left == right)`.
Missing required operand-type information can fail analysis rather than produce
a clean nonfinding.

Choose a tolerance based on the domain; one universal epsilon is not correct
for every magnitude or calculation.
