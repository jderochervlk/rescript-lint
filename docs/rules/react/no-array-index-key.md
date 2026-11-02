# `react/no-array-index-key`

Avoid using a collection's position as the React key.

- Category: `perf`
- Enabled by default: No
- Autofix: No

Index keys can associate component state with the wrong item when a collection is reordered or edited. The rule checks the actual index parameter in supported standard and Belt mapping callbacks.
It follows the callback's index binding even when renamed or converted to a
string for the key.

## Examples

### Incorrect

```rescript
let rows = users->Array.mapWithIndex((user, index) =>
  <li key={index->Int.toString}> {React.string(user.name)} </li>
)
```

### Correct

```rescript
let rows = users->Array.map(user =>
  <li key={user.id}> {React.string(user.name)} </li>
)
```

## Configuration

`false` disables this rule.

```json
{
  "jsxRuntime": "react-dom",
  "rules": {"react/no-array-index-key": true}
}
```

Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Only supported mapping APIs and their resolved index bindings are analyzed; arbitrary helper-generated keys are outside the check. Missing adapter metadata is an analysis error.
