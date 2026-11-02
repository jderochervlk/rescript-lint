# `react/no-unstable-nested-components`

Declare React components outside the render function that uses them.

- Category: `suspicious`
- Enabled by default: No
- Autofix: No

Nested component declarations are recreated during render and can cause subtree remounts. `false` disables the rule.

## Examples
### Incorrect
```rescript
@react.component
let make = () => {
  module Row = {
    @react.component
    let make = (~text) => <span> {React.string(text)} </span>
  }
  <Row text="Nested" />
}
```
### Correct
```rescript
module Row = {
  @react.component
  let make = (~text) => <span> {React.string(text)} </span>
}
@react.component
let make = () => <Row text="Stable" />
```

## Configuration
```json
{"jsxRuntime":"react-dom","rules":{"react/no-unstable-nested-components":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Recognizes component declarations in supported render contexts; it does not establish runtime identity for arbitrary helpers. Missing adapter information is an analysis error.

See [examples](../RULE_EXAMPLES.md#react-rules) and [boundaries](../EXTENDED_RULES.md#react-rules).
