# `react/no-new-prop-value`

Avoid passing freshly created values as component props during render.

- Category: `perf`
- Enabled by default: No
- Autofix: No

New arrays, records, tuples, or functions have new identities and may trigger unnecessary child work. Special props are excluded. `false` disables this rule.

## Examples
### Incorrect
```rescript
@react.component
let make = () => <ItemList items={[1, 2, 3]} onSelect={item => select(item)} />
```
### Correct
```rescript
let stableItems = [1, 2, 3]
let handleSelect = item => select(item)
@react.component
let make = () => <ItemList items=stableItems onSelect=handleSelect />
```

## Configuration
```json
{"jsxRuntime":"react-dom","rules":{"react/no-new-prop-value":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Only statically recognized fresh values in supported JSX props are reported; it is not a general memoization recommendation. Missing adapter configuration is an analysis error.
