# `react/jsx-no-constructed-context-values`

Avoid constructing a fresh context provider value during every render.

- Category: `perf`
- Enabled by default: No
- Autofix: No

Fresh records, arrays, or functions can make consumers update even when their contents are unchanged. The check applies to resolved `React.Context.provider` values. `false` disables the rule.

## Examples
### Incorrect
```rescript
type theme = {color: string}
let defaultTheme = {color: "blue"}
let themeContext = React.createContext(defaultTheme)
module ThemeContext = {
  let make = React.Context.provider(themeContext)
}

@react.component
let make = (~children) =>
  <ThemeContext value={{color: "blue"}}> children </ThemeContext>
```
### Correct
```rescript
type theme = {color: string}
let defaultTheme = {color: "blue"}
let themeContext = React.createContext(defaultTheme)
module ThemeContext = {
  let make = React.Context.provider(themeContext)
}

@react.component
let make = (~children) =>
  <ThemeContext value=defaultTheme> children </ThemeContext>
```

## Configuration
```json
{"jsxRuntime":"react-dom","rules":{"react/jsx-no-constructed-context-values":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Only resolved providers and statically recognized fresh values are checked; this is not a general render profiler. Missing adapter configuration is an analysis error.

See [examples](../RULE_EXAMPLES.md#react-rules) and [boundaries](../EXTENDED_RULES.md#react-rules).
