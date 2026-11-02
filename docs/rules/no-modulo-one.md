# `no-modulo-one`

Flags integer remainder operations by one or negative one.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

The rule recognizes `%` and the resolved standard `mod` function when the divisor is literal `1` or `-1`. It excludes floats and shadowed functions named `mod`.

## Examples

### Incorrect

```rescript
let calculate = (value: int) => value % 1
```

### Correct

```rescript
let calculate = (value: int) => value % 2
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "no-modulo-one": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.

See [Additional Opt-in Policies](POLICY_EXPANSION.md#additional-opt-in-policies).
