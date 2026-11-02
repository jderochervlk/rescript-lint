# `max-switch-cases`

Limits the number of arms in a switch expression.

- Category: `pedantic`
- Enabled by default: No
- Autofix: No

Each syntactic switch arm counts once, including guarded arms; an or-pattern within an arm counts once. Catch handlers are not switch arms. Set `maxSwitchCases` to a nonnegative integer; the default threshold is 10. Setting a threshold does not enable the rule.

## Examples

### Incorrect

With `maxSwitchCases` set to `2`, this switch has three arms:

```rescript
let classify = value => switch value {
| 0 => "zero"
| 1 => "one"
| _ => "other"
}
```

### Correct

```rescript
let classify = value => switch value {
| 0 => "zero"
| _ => "other"
}
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. `maxSwitchCases` accepts zero or greater.

```json
{
  "rules": {
    "max-switch-cases": true
  },
  "maxSwitchCases": 2
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.

See [Additional Opt-in Policies](POLICY_EXPANSION.md#additional-opt-in-policies).
