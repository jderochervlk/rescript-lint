# `no-expensive-deep-equality`

Report structural equality whose known type risk is at or above a configured threshold.

- Category: `perf`
- Enabled by default: No
- Autofix: No

Prefer comparing a stable, suitably chosen key when whole-value comparison is unnecessary. This check estimates structural risk; it does not measure runtime cost.

## Examples

### Incorrect

```rescript
type state = {version: int, items: array<int>}
let unchanged = (currentState: state, cachedState: state) =>
  currentState == cachedState
```

### Correct

```rescript
type state = {version: int, items: array<int>}
let unchanged = (currentState: state, cachedState: state) =>
  currentState.version === cachedState.version
```

The key comparison is appropriate only when the application guarantees that
`version` changes whenever the relevant state changes.

## Configuration

```json
{
  "rules": {
    "no-expensive-deep-equality": true
  },
  "deepEqualityThreshold": 2
}
```

The shown example uses the configured threshold `2`; the default is `4`.
`deepEqualityThreshold` must be an integer of at least 2.
Set this rule to `false` to disable it.
Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Only structural comparisons whose inferred type risk is at or above the
threshold are reported. Unknown type facts are not treated as proof of cost or
safety.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#no-expensive-deep-equality).
