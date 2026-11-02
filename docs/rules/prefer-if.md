# `prefer-if`

Prefers an `if` expression over a two-case switch on a boolean.

- Category: `style`
- Enabled by default: No
- Autofix: No

The switch must have distinct `true` and `false` patterns and no guards. It may overlap with `simplify-boolean-expression` when the result arms are boolean literals.

## Examples

### Incorrect

```rescript
let choose = ready => switch ready {| true => 1 | false => 2}
```

### Correct

```rescript
let choose = ready => if ready {1} else {2}
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "prefer-if": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.

See [Additional Opt-in Policies](POLICY_EXPANSION.md#additional-opt-in-policies).
