# `react/exhaustive-deps`

Include captured reactive values in supported React hook dependency lists.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Effects and other supported hooks can observe stale values when a callback captures a changing value omitted from its dependencies. Checks cover recognized numbered ReScript bindings and dependency arrays/tuples. `false` disables the rule.

## Examples
### Incorrect
```rescript
@react.component
let make = (~userId, ~loadUser) => {
  React.useEffect1(() => {
    loadUser(userId)
    None
  }, [])
  React.null
}
```
### Correct
```rescript
@react.component
let make = (~userId, ~loadUser) => {
  React.useEffect2(() => {
    loadUser(userId)
    None
  }, (userId, loadUser))
  React.null
}
```

## Configuration
```json
{"jsxRuntime":"react-dom","rules":{"react/exhaustive-deps":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Tracks identity/field paths, aliases and shadowing; excludes module-level values and known stable setters/refs. Arbitrary custom-hook contracts and dynamic callback/dependency expressions can remain unknown. Findings are not rewritten. Missing adapter or required analysis information is an analysis error, distinct from a clean result.

See [current examples](../RULE_EXAMPLES.md#react-rules) and [analysis boundaries](../EXTENDED_RULES.md#react-rules).
