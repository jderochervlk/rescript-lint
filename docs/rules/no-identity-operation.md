# `no-identity-operation`

Flags known integer operations that leave their value unchanged.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Recognized forms are `x + 0`, `0 + x`, `x - 0`, `x * 1`, `1 * x`, and `x / 1`, when both operands are known integers. Floating-point and unknown-type operands are excluded.

## Examples

### Incorrect

```rescript
let calculate = (value: int) => value + 0
```

### Correct

```rescript
let calculate = (value: int) => value
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "no-identity-operation": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.
