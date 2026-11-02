# `no-erasing-operation`

Flags known integer multiplication by zero.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

The diagnostic applies when either integer operand is the literal zero. Simplifying such an expression must preserve evaluation effects from the other operand; no automatic rewrite is provided.

## Examples

### Incorrect

```rescript
let calculate = (value: int) => value * 0
```

### Correct

```rescript
let calculate = (value: int) => value * 2
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "no-erasing-operation": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.
