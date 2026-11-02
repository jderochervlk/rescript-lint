# `no-for`

Disallows syntactic counting loops in either direction.

- Category: `restriction`
- Enabled by default: No
- Autofix: No

Consider a collection operation or explicit recursion instead. Collection callbacks are not counted as `for` loops by this rule.

## Examples

### Incorrect

```rescript
let visit = work => {for i in 0 to 2 {work(i)}}
```

### Correct

```rescript
let visit = work => [0, 1, 2]->Array.forEach(work)
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "no-for": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.

See [Additional Opt-in Policies](POLICY_EXPANSION.md#additional-opt-in-policies).
