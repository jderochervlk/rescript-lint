# `no-nested-ternary`

Disallows a ternary expression that immediately contains another ternary.

- Category: `style`
- Enabled by default: No
- Autofix: No

Extract the decision into a clearer structure or use nested `if` expressions. Nesting in the condition or either result arm is detected, including through type constraints; ordinary nested `if` expressions are not ternaries.

## Examples

### Incorrect

```rescript
let choose = (a, b) => a ? (b ? 1 : 2) : 3
```

### Correct

```rescript
let choose = (a, b) => if a {if b {1} else {2}} else {3}
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "no-nested-ternary": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.

See [Additional Opt-in Policies](POLICY_EXPANSION.md#additional-opt-in-policies).
