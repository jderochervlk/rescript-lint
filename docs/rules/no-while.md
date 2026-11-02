# `no-while`

Disallows syntactic `while` loops.

- Category: `restriction`
- Enabled by default: No
- Autofix: No

Consider a collection operation or explicit recursion instead. This opt-in policy flags every `while` loop, including intentional imperative loops.

## Examples

### Incorrect

```rescript
let visit = (ready, work) => {while ready() {work()}}
```

### Correct

```rescript
let visit = (values, work) => values->Array.forEach(work)
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "no-while": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.

See [Additional Opt-in Policies](POLICY_EXPANSION.md#additional-opt-in-policies).
