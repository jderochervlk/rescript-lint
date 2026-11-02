# `no-record-mutation`

Disallows assignments to record fields.

- Category: `restriction`
- Enabled by default: No
- Autofix: No

Prefer creating a record with the changed field rather than changing a field in place. This policy also detects assignments to reference-cell fields; it does not claim to cover every form of mutation.

## Examples

### Incorrect

```rescript
type state = {mutable count: int}
let update = (state: state) => {state.count = 2}
```

### Correct

```rescript
type state = {count: int}
let update = (state: state) => {...state, count: 2}
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "no-record-mutation": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.

See [Additional Opt-in Policies](POLICY_EXPANSION.md#additional-opt-in-policies).
